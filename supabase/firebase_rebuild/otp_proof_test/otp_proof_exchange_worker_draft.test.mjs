import assert from 'node:assert/strict';
import { generateKeyPairSync, sign as rsaSign, webcrypto } from 'node:crypto';
import test from 'node:test';
import { createExchangeWorker, issueOtpTicket } from './otp_proof_exchange_worker_draft.mjs';

globalThis.crypto ??= webcrypto;
const projectId = 'schoolivia-native-test';
const now = 1_800_000_000;
const otpSecret = 'test-only-otp-proof-secret-at-least-32-bytes';
const supabaseSecret = 'test-only-supabase-jwt-secret-at-least-32-bytes';
const { publicKey, privateKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { format: 'jwk' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
});
const env = { FIREBASE_PROJECT_ID: projectId, OTP_PROOF_SECRET: otpSecret, SUPABASE_JWT_SECRET: supabaseSecret };
const worker = createExchangeWorker({
  now: () => now,
  fetchImpl: async () => new Response(JSON.stringify({ keys: [{ ...publicKey, kid: 'test-kid', alg: 'RS256', use: 'sig' }] }), {
    status: 200, headers: { 'content-type': 'application/json' },
  }),
});

function base64url(value) {
  return Buffer.from(typeof value === 'string' ? value : JSON.stringify(value)).toString('base64url');
}
function firebaseToken({
  uid = 'firebase-test-uid',
  email = 'student@example.invalid',
  aud = projectId,
  iss = `https://securetoken.google.com/${projectId}`,
  exp = now + 3600,
  iat = now,
  kid = 'test-kid',
  signingKey = privateKey,
} = {}) {
  const header = base64url({ alg: 'RS256', typ: 'JWT', kid });
  const payload = base64url({
    iss, aud, sub: uid, email, email_verified: false, iat, exp, auth_time: iat,
  });
  const input = `${header}.${payload}`;
  return `${input}.${rsaSign('RSA-SHA256', Buffer.from(input), signingKey).toString('base64url')}`;
}
async function ticket(overrides = {}) {
  return issueOtpTicket({
    secret: otpSecret, projectId, email: 'student@example.invalid',
    purpose: 'student.register', jti: 'test-registration-jti-0001',
    nowSeconds: now, expiresInSeconds: 180, ...overrides,
  });
}
async function exchange(options = {}) {
  const idToken = options.idToken ?? firebaseToken();
  const otpTicket = options.otpTicket ?? await ticket();
  const workerInstance = options.workerInstance ?? worker;
  return workerInstance.fetch(new Request('https://test.invalid/exchange', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ firebase_id_token: idToken, otp_ticket: otpTicket }),
  }), env);
}
function jwtPayload(token) {
  return JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
}
async function verifyHs256(token, secret) {
  const [header, payload, signature] = token.split('.');
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
  return crypto.subtle.verify('HMAC', key, Buffer.from(signature, 'base64url'), new TextEncoder().encode(`${header}.${payload}`));
}

test('valid Firebase ID token plus OTP ticket yields a short-lived Supabase JWT with exact DB claims', async () => {
  const response = await exchange();
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.token_type, 'bearer');
  assert.equal(body.expires_in, 180);
  assert.equal(await verifyHs256(body.access_token, supabaseSecret), true);
  const claims = jwtPayload(body.access_token);
  assert.equal(claims.iss, `https://securetoken.google.com/${projectId}`);
  assert.equal(claims.aud, projectId);
  assert.equal(claims.role, 'authenticated');
  assert.equal(claims.sub, 'firebase-test-uid');
  assert.equal(claims.email, 'student@example.invalid');
  assert.equal(claims.email_verified, false, 'OTP proof is independent of Firebase emailVerified');
  assert.equal(claims.otp_verified, true);
  assert.equal(claims.otp_uid, claims.sub);
  assert.equal(claims.otp_email, claims.email);
  assert.equal(claims.otp_purpose, 'student.register');
  assert.equal(claims.otp_jti, 'test-registration-jti-0001');
  assert.equal(claims.otp_exp, now + 180);
  assert.ok(claims.exp <= now + 300);
  assert.equal(Object.hasOwn(claims, 'service_role'), false);
});

test('supports ES256 Supabase signing keys used by PostgREST JWK configurations', async () => {
  const { publicKey: supabasePublicKey, privateKey: supabasePrivateKey } = generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
    publicKeyEncoding: { format: 'jwk' },
    privateKeyEncoding: { format: 'jwk' },
  });
  const kid = 'schoolivia-test-es256';
  const es256Worker = createExchangeWorker({
    now: () => now,
    fetchImpl: async () => new Response(JSON.stringify({ keys: [{ ...publicKey, kid: 'test-kid', alg: 'RS256', use: 'sig' }] }), {
      status: 200, headers: { 'content-type': 'application/json' },
    }),
  });
  const response = await es256Worker.fetch(new Request('https://test.invalid/exchange', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ firebase_id_token: firebaseToken(), otp_ticket: await ticket() }),
  }), {
    ...env,
    SUPABASE_JWT_SECRET: undefined,
    SUPABASE_JWT_PRIVATE_JWK: JSON.stringify(supabasePrivateKey),
    SUPABASE_JWT_KID: kid,
  });
  assert.equal(response.status, 200);
  const body = await response.json();
  const [header, payload, signature] = body.access_token.split('.');
  const decodedHeader = JSON.parse(Buffer.from(header, 'base64url').toString('utf8'));
  assert.equal(decodedHeader.alg, 'ES256');
  assert.equal(decodedHeader.kid, kid);
  const verifyKey = await crypto.subtle.importKey('jwk', supabasePublicKey, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
  const valid = await crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    verifyKey,
    Buffer.from(signature, 'base64url'),
    new TextEncoder().encode(`${header}.${payload}`),
  );
  assert.equal(valid, true);
  assert.equal(jwtPayload(body.access_token).sub, 'firebase-test-uid');
});

test('rejects a ticket bound to another email', async () => {
  const response = await exchange({ otpTicket: await ticket({ email: 'other@example.invalid' }) });
  assert.equal(response.status, 401);
});

test('rejects a ticket with an unsupported registration purpose', async () => {
  const invalidTicket = await issueOtpTicket({
    secret: otpSecret, projectId, email: 'student@example.invalid',
    purpose: 'student.register', jti: 'test-purpose-jti-0001',
    nowSeconds: now, expiresInSeconds: 180,
  });
  const [h, p, s] = invalidTicket.split('.');
  const payload = { ...JSON.parse(Buffer.from(p, 'base64url').toString()), purpose: 'password.reset' };
  const changed = `${h}.${base64url(payload)}`;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(otpSecret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(changed));
  const forgedPurposeTicket = `${changed}.${Buffer.from(signature).toString('base64url')}`;
  const response = await exchange({ otpTicket: forgedPurposeTicket });
  assert.equal(response.status, 401);
});

test('rejects an expired OTP ticket', async () => {
  const expired = await ticket({ nowSeconds: now - 200, expiresInSeconds: 100 });
  const response = await exchange({ otpTicket: expired });
  assert.equal(response.status, 401);
});

test('rejects Firebase ID tokens from another project', async () => {
  const response = await exchange({ idToken: firebaseToken({ aud: 'wrong-project', iss: 'https://securetoken.google.com/wrong-project' }) });
  assert.equal(response.status, 401);
});

test('rejects expired Firebase ID tokens', async () => {
  const response = await exchange({ idToken: firebaseToken({ exp: now - 1 }) });
  assert.equal(response.status, 401);
});

test('rejects forged Firebase ID-token signatures', async () => {
  const { privateKey: otherPrivateKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    publicKeyEncoding: { format: 'jwk' },
  });
  const response = await exchange({ idToken: firebaseToken({ signingKey: otherPrivateKey }) });
  assert.equal(response.status, 401);
});

test('rejects unknown Firebase signing key IDs', async () => {
  const response = await exchange({ idToken: firebaseToken({ kid: 'unknown-kid' }) });
  assert.equal(response.status, 401);
});

test('rejects malformed request bodies and wrong methods without issuing tokens', async () => {
  const wrongMethod = await worker.fetch(new Request('https://test.invalid/exchange', { method: 'GET' }), env);
  assert.equal(wrongMethod.status, 404);
  const wrongType = await worker.fetch(new Request('https://test.invalid/exchange', { method: 'POST', body: '{}' }), env);
  assert.equal(wrongType.status, 415);
  const badBody = await worker.fetch(new Request('https://test.invalid/exchange', {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}',
  }), env);
  assert.equal(badBody.status, 400);
});

test('fails closed when signing secrets are not configured', async () => {
  const response = await worker.fetch(new Request('https://test.invalid/exchange', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ firebase_id_token: firebaseToken(), otp_ticket: await ticket() }),
  }), { FIREBASE_PROJECT_ID: projectId });
  assert.equal(response.status, 503);
});

test('same signed ticket keeps one jti across exchanges for database-side one-time consumption', async () => {
  const otpTicket = await ticket();
  const first = await exchange({ otpTicket });
  const second = await exchange({ otpTicket });
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.equal(jwtPayload((await first.json()).access_token).otp_jti, 'test-registration-jti-0001');
  assert.equal(jwtPayload((await second.json()).access_token).otp_jti, 'test-registration-jti-0001');
});
