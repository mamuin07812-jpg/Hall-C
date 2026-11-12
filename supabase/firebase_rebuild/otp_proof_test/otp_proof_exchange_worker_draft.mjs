const encoder = new TextEncoder();
const PROJECT_ISSUER = (projectId) => `https://securetoken.google.com/${projectId}`;
const OTP_ISSUER = 'schoolivia-otp-worker';
const ALLOWED_PURPOSES = new Set(['student.register', 'teacher.register']);

function encodeBase64Url(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
function decodeBase64Url(value) {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - normalized.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, char => char.charCodeAt(0));
}
function parseSegment(value) {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(value)));
}
function splitJwt(value) {
  if (typeof value !== 'string') throw new Error('invalid token');
  const parts = value.split('.');
  if (parts.length !== 3 || parts.some(part => !part)) throw new Error('invalid token');
  return parts;
}
function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}
function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}
function validEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}
async function importHmac(secret, usages) {
  if (typeof secret !== 'string' || secret.length < 32) throw new Error('signing secret unavailable');
  return crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, usages);
}
async function signHmacJwt(payload, secret, header = { alg: 'HS256', typ: 'JWT' }) {
  const encodedHeader = encodeBase64Url(encoder.encode(JSON.stringify(header)));
  const encodedPayload = encodeBase64Url(encoder.encode(JSON.stringify(payload)));
  const input = `${encodedHeader}.${encodedPayload}`;
  const key = await importHmac(secret, ['sign']);
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(input));
  return `${input}.${encodeBase64Url(new Uint8Array(signature))}`;
}
async function verifyHmacJwt(token, secret, nowSeconds) {
  const [headerPart, payloadPart, signaturePart] = splitJwt(token);
  const header = parseSegment(headerPart);
  if (header.alg !== 'HS256' || header.typ !== 'JWT') throw new Error('invalid token');
  const key = await importHmac(secret, ['verify']);
  const valid = await crypto.subtle.verify('HMAC', key, decodeBase64Url(signaturePart), encoder.encode(`${headerPart}.${payloadPart}`));
  if (!valid) throw new Error('invalid token');
  const claims = parseSegment(payloadPart);
  if (!Number.isInteger(claims.exp) || claims.exp <= nowSeconds) throw new Error('expired token');
  if (!Number.isInteger(claims.iat) || claims.iat > nowSeconds + 60) throw new Error('invalid token time');
  return claims;
}

/**
 * Call only after the existing OTP verifier has accepted and consumed the code.
 * The ticket is intentionally email+purpose bound because the current app
 * creates the Firebase Auth identity after its OTP step.
 */
export async function issueOtpTicket({
  secret, projectId, email, purpose, jti = crypto.randomUUID(),
  nowSeconds = Math.floor(Date.now() / 1000), expiresInSeconds = 180,
}) {
  const normalizedEmail = normalizeEmail(email);
  if (!projectId || !validEmail(normalizedEmail) || !ALLOWED_PURPOSES.has(purpose)) {
    throw new Error('invalid OTP ticket input');
  }
  if (!Number.isInteger(expiresInSeconds) || expiresInSeconds < 1 || expiresInSeconds > 300) {
    throw new Error('invalid OTP ticket lifetime');
  }
  if (typeof jti !== 'string' || jti.trim().length < 16) throw new Error('invalid OTP ticket id');
  return signHmacJwt({
    iss: OTP_ISSUER,
    aud: projectId,
    email: normalizedEmail,
    purpose,
    jti: jti.trim(),
    iat: nowSeconds,
    exp: nowSeconds + expiresInSeconds,
  }, secret);
}

export async function verifyFirebaseIdToken(token, projectId, fetchImpl = fetch, nowSeconds = Math.floor(Date.now() / 1000)) {
  const [headerPart, payloadPart, signaturePart] = splitJwt(token);
  const header = parseSegment(headerPart);
  if (header.alg !== 'RS256' || typeof header.kid !== 'string' || !header.kid) throw new Error('invalid Firebase token header');
  const response = await fetchImpl('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
  if (!response.ok) throw new Error('Firebase signing keys unavailable');
  const jwks = await response.json();
  const jwk = Array.isArray(jwks.keys) ? jwks.keys.find(key => key.kid === header.kid && key.kty === 'RSA') : null;
  if (!jwk) throw new Error('unknown Firebase signing key');
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5', key, decodeBase64Url(signaturePart), encoder.encode(`${headerPart}.${payloadPart}`),
  );
  if (!valid) throw new Error('invalid Firebase token signature');
  const claims = parseSegment(payloadPart);
  if (claims.iss !== PROJECT_ISSUER(projectId) || claims.aud !== projectId) throw new Error('wrong Firebase project');
  if (typeof claims.sub !== 'string' || !claims.sub.trim() || claims.sub.length > 128) throw new Error('invalid Firebase UID');
  if (!validEmail(normalizeEmail(claims.email))) throw new Error('Firebase email missing');
  if (!Number.isInteger(claims.exp) || claims.exp <= nowSeconds) throw new Error('expired Firebase token');
  if (!Number.isInteger(claims.iat) || claims.iat > nowSeconds + 60) throw new Error('invalid Firebase token time');
  return { ...claims, email: normalizeEmail(claims.email) };
}

export function createExchangeWorker({ fetchImpl = fetch, now = () => Math.floor(Date.now() / 1000) } = {}) {
  return {
    async fetch(request, env) {
      const url = new URL(request.url);
      if (request.method !== 'POST' || url.pathname !== '/exchange') return json({ ok: false, error: 'Not found' }, 404);
      if (!request.headers.get('content-type')?.toLowerCase().includes('application/json')) {
        return json({ ok: false, error: 'Invalid request' }, 415);
      }
      try {
        const body = await request.json();
        if (!body || typeof body.firebase_id_token !== 'string' || typeof body.otp_ticket !== 'string') {
          return json({ ok: false, error: 'Invalid request' }, 400);
        }
        const projectId = env.FIREBASE_PROJECT_ID;
        if (!projectId || !env.OTP_PROOF_SECRET || !env.SUPABASE_JWT_SECRET) {
          return json({ ok: false, error: 'Exchange is not configured' }, 503);
        }
        const timestamp = now();
        const [firebaseClaims, otpClaims] = await Promise.all([
          verifyFirebaseIdToken(body.firebase_id_token, projectId, fetchImpl, timestamp),
          verifyHmacJwt(body.otp_ticket, env.OTP_PROOF_SECRET, timestamp),
        ]);
        const email = normalizeEmail(firebaseClaims.email);
        if (otpClaims.iss !== OTP_ISSUER || otpClaims.aud !== projectId ||
            !ALLOWED_PURPOSES.has(otpClaims.purpose) || normalizeEmail(otpClaims.email) !== email ||
            typeof otpClaims.jti !== 'string' || otpClaims.jti.trim().length < 16 ||
            !Number.isInteger(otpClaims.exp) || otpClaims.exp > timestamp + 300) {
          return json({ ok: false, error: 'Registration proof rejected' }, 401);
        }
        const expiresAt = Math.min(firebaseClaims.exp, otpClaims.exp, timestamp + 300);
        if (expiresAt <= timestamp) return json({ ok: false, error: 'Registration proof expired' }, 401);
        const supabaseClaims = {
          iss: PROJECT_ISSUER(projectId),
          aud: projectId,
          sub: firebaseClaims.sub,
          role: 'authenticated',
          email,
          email_verified: firebaseClaims.email_verified === true,
          iat: timestamp,
          exp: expiresAt,
          otp_verified: true,
          otp_uid: firebaseClaims.sub,
          otp_email: email,
          otp_purpose: otpClaims.purpose,
          otp_jti: otpClaims.jti,
          otp_exp: otpClaims.exp,
        };
        const accessToken = await signHmacJwt(supabaseClaims, env.SUPABASE_JWT_SECRET);
        return json({ access_token: accessToken, token_type: 'bearer', expires_in: expiresAt - timestamp });
      } catch {
        return json({ ok: false, error: 'Registration exchange rejected' }, 401);
      }
    },
  };
}

export default createExchangeWorker();
