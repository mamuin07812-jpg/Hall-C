import { createExchangeWorker, issueOtpTicket } from './otp_proof_exchange_worker_draft.mjs';

const OTP_TTL_SECONDS = 300;
const MAX_ATTEMPTS = 5;
const RESEND_COOLDOWN_SECONDS = 60;
const PURPOSES = new Set(['student.register', 'teacher.register']);
const encoder = new TextEncoder();

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
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
async function sha256(value) {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(value));
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
}
function generateOtp() {
  return String(crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000).padStart(6, '0');
}
async function readBody(request) {
  try { return await request.json(); } catch { return null; }
}
async function requestOtp(request, env) {
  const body = await readBody(request);
  if (!body || typeof body.email !== 'string') return json({ ok: false, error: 'Invalid request' }, 400);
  const email = normalizeEmail(body.email);
  if (!validEmail(email)) return json({ ok: false, error: 'Invalid email' }, 400);
  const purpose = body.purpose == null || body.purpose === '' ? null : body.purpose;
  if (purpose !== null && !PURPOSES.has(purpose)) {
    return json({ ok: false, error: 'Unsupported registration purpose' }, 400);
  }
  if (purpose && (!env.OTP_PROOF_SECRET || !env.FIREBASE_PROJECT_ID)) {
    return json({ ok: false, error: 'Registration proof is not configured' }, 503);
  }

  try {
    const now = Math.floor(Date.now() / 1000);
    const recent = await env.DB.prepare(
      'SELECT id, last_sent_at FROM otp_challenges WHERE email = ? ORDER BY id DESC LIMIT 1',
    ).bind(email).first();
    if (recent && now - Number(recent.last_sent_at) < RESEND_COOLDOWN_SECONDS) {
      return json({ ok: false, error: 'Please wait before requesting another code' }, 429);
    }

    const otp = env.TEST_OTP_CODE || generateOtp();
    if (!/^\d{6}$/.test(otp)) return json({ ok: false, error: 'OTP generator failed' }, 503);
    const codeHash = await sha256(email + ':' + otp + ':' + env.OTP_HASH_SECRET);
    const expiresAt = now + OTP_TTL_SECONDS;
    await env.DB.prepare('DELETE FROM otp_challenges WHERE email = ?').bind(email).run();
    await env.DB.prepare(
      'INSERT INTO otp_challenges (email, code_hash, expires_at, attempts, max_attempts, created_at, last_sent_at, purpose) VALUES (?, ?, ?, 0, ?, ?, ?, ?)',
    ).bind(email, codeHash, expiresAt, MAX_ATTEMPTS, now, now, purpose).run();

    // The plaintext outbox exists only in the disposable Miniflare fixture.
    // The production Worker must continue using its existing sendEmail() path.
    if (env.TEST_MODE === 'true') {
      await env.DB.prepare(
        'INSERT INTO otp_test_outbox (email, code, created_at) VALUES (?, ?, ?)',
      ).bind(email, otp, now).run();
    }
    return json({ ok: true, message: 'Verification code sent', expiresIn: OTP_TTL_SECONDS });
  } catch {
    return json({ ok: false, error: 'OTP service temporarily unavailable' }, 503);
  }
}

async function verifyOtp(request, env) {
  const body = await readBody(request);
  if (!body || typeof body.email !== 'string' || typeof body.code !== 'string') {
    return json({ ok: false, error: 'Invalid request' }, 400);
  }
  const email = normalizeEmail(body.email);
  const code = body.code.trim();
  if (!validEmail(email) || !/^\d{6}$/.test(code)) {
    return json({ ok: false, error: 'Invalid verification data' }, 400);
  }

  try {
    const challenge = await env.DB.prepare(
      'SELECT * FROM otp_challenges WHERE email = ? ORDER BY id DESC LIMIT 1',
    ).bind(email).first();
    if (!challenge) return json({ ok: false, error: 'No active verification code' }, 400);

    const now = Math.floor(Date.now() / 1000);
    if (now > Number(challenge.expires_at)) {
      await env.DB.prepare('DELETE FROM otp_challenges WHERE id = ?').bind(challenge.id).run();
      return json({ ok: false, error: 'Verification code expired' }, 400);
    }
    if (Number(challenge.attempts) >= Number(challenge.max_attempts)) {
      await env.DB.prepare('DELETE FROM otp_challenges WHERE id = ?').bind(challenge.id).run();
      return json({ ok: false, error: 'Too many attempts' }, 429);
    }

    const codeHash = await sha256(email + ':' + code + ':' + env.OTP_HASH_SECRET);
    if (codeHash !== challenge.code_hash) {
      await env.DB.prepare(
        'UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = ? AND attempts < max_attempts',
      ).bind(challenge.id).run();
      return json({ ok: false, error: 'Incorrect verification code' }, 400);
    }

    const purpose = challenge.purpose || null;
    let otpTicket = null;
    if (purpose) {
      if (!PURPOSES.has(purpose) || !env.OTP_PROOF_SECRET || !env.FIREBASE_PROJECT_ID) {
        return json({ ok: false, error: 'Registration proof is not configured' }, 503);
      }
      // Prepare the signed ticket before consuming the challenge. It is only
      // returned if the conditional DELETE below proves this request won.
      otpTicket = await issueOtpTicket({
        secret: env.OTP_PROOF_SECRET,
        projectId: env.FIREBASE_PROJECT_ID,
        email,
        purpose,
        expiresInSeconds: Math.min(OTP_TTL_SECONDS, 180),
      });
    }

    // Atomic single-use consumption: concurrent verifiers can read the same
    // row, but only one conditional DELETE can report changes=1.
    const consumed = await env.DB.prepare(
      'DELETE FROM otp_challenges WHERE id = ? AND code_hash = ? AND expires_at >= ? AND attempts < max_attempts',
    ).bind(challenge.id, challenge.code_hash, now).run();
    if (Number(consumed.meta?.changes ?? 0) !== 1) {
      return json({ ok: false, error: 'Verification code already used or expired' }, 409);
    }

    // Legacy clients that omit purpose receive the exact existing response.
    if (!purpose) return json({ ok: true, verified: true });
    return json({ ok: true, verified: true, purpose, otp_ticket: otpTicket });
  } catch {
    return json({ ok: false, error: 'OTP service temporarily unavailable' }, 503);
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== 'POST') return json({ ok: false, error: 'Not found' }, 404);
    if (!request.headers.get('content-type')?.toLowerCase().includes('application/json')) {
      return json({ ok: false, error: 'Invalid request' }, 415);
    }
    if (url.pathname === '/request-otp') return requestOtp(request, env);
    if (url.pathname === '/verify-otp') return verifyOtp(request, env);
    if (url.pathname === '/exchange') {
      const exchangeWorker = createExchangeWorker({
        fetchImpl: async (target, init) => {
          if (env.TEST_MODE === 'true' && env.TEST_JWKS_JSON) {
            return new Response(env.TEST_JWKS_JSON, { status: 200, headers: { 'content-type': 'application/json' } });
          }
          return fetch(target, init);
        },
      });
      return exchangeWorker.fetch(request, env);
    }
    return json({ ok: false, error: 'Not found' }, 404);
  },
};
