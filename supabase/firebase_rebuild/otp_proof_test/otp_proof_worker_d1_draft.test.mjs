import assert from 'node:assert/strict';
import { generateKeyPairSync, sign as rsaSign, webcrypto } from 'node:crypto';
import test, { after, before } from 'node:test';
import { Miniflare } from 'miniflare';
import { createExchangeWorker } from './otp_proof_exchange_worker_draft.mjs';

globalThis.crypto ??= webcrypto;

const projectId = 'schoolivia-native-test';
const otpHashSecret = 'test-only-otp-hash-secret';
const otpProofSecret = 'test-only-otp-proof-secret-at-least-32-bytes';
const supabaseJwtSecret = 'test-only-supabase-jwt-secret-at-least-32-bytes';
const workerPath = new URL('./otp_proof_worker_d1_draft.mjs', import.meta.url).pathname;
let mf;
let db;

async function createSchema() {
  await db.prepare(`CREATE TABLE IF NOT EXISTS otp_challenges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    code_hash TEXT NOT NULL,
    expires_at INTEGER NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 5,
    created_at INTEGER NOT NULL,
    last_sent_at INTEGER NOT NULL,
    purpose TEXT
  )`).run();
  await db.prepare('CREATE INDEX IF NOT EXISTS otp_challenges_email_id_idx ON otp_challenges(email, id DESC)').run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS otp_test_outbox (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    code TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )`).run();
}

async function resetDb() {
  await db.prepare('DELETE FROM otp_challenges').run();
  await db.prepare('DELETE FROM otp_test_outbox').run();
}
async function requestOtp(email, purpose) {
  const body = { email };
  if (purpose !== undefined) body.purpose = purpose;
  return mf.dispatchFetch('https://schoolivia-test.invalid/request-otp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
}
async function verifyOtp(email, code) {
  return mf.dispatchFetch('https://schoolivia-test.invalid/verify-otp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, code }),
  });
}
async function capturedCode(email) {
  const row = await db.prepare(
    'SELECT code FROM otp_test_outbox WHERE email = ? ORDER BY id DESC LIMIT 1',
  ).bind(email).first();
  assert.ok(row, 'test delivery outbox should contain a code');
  return row.code;
}
function decodeJwtPayload(token) {
  return JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
}
function makeFirebaseToken({ uid, email, privateKey, nowSeconds }) {
  const b64 = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const header = b64({ alg: 'RS256', typ: 'JWT', kid: 'miniflare-test-key' });
  const payload = b64({
    iss: `https://securetoken.google.com/${projectId}`,
    aud: projectId,
    sub: uid,
    email,
    email_verified: false,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
    auth_time: nowSeconds,
  });
  const input = `${header}.${payload}`;
  return `${input}.${rsaSign('RSA-SHA256', Buffer.from(input), privateKey).toString('base64url')}`;
}

before(async () => {
  mf = new Miniflare({
    scriptPath: workerPath,
    modules: true,
    compatibilityDate: '2026-11-12',
    d1Databases: { DB: 'schoolivia-otp-proof-d1-test' },
    bindings: {
      TEST_MODE: 'true',
      TEST_OTP_CODE: '246810',
      OTP_HASH_SECRET: otpHashSecret,
      OTP_PROOF_SECRET: otpProofSecret,
      SUPABASE_JWT_SECRET: supabaseJwtSecret,
      FIREBASE_PROJECT_ID: projectId,
    },
  });
  await mf.ready;
  db = await mf.getD1Database('DB');
  await createSchema();
});

after(async () => {
  await mf?.dispose();
});

test('legacy OTP clients retain the exact verified response and cannot obtain a registration ticket', async () => {
  await resetDb();
  const email = 'legacy@example.invalid';
  const requested = await requestOtp(email);
  assert.equal(requested.status, 200);
  const verified = await verifyOtp(email, await capturedCode(email));
  assert.equal(verified.status, 200);
  assert.deepEqual(await verified.json(), { ok: true, verified: true });
  const replay = await verifyOtp(email, '246810');
  assert.equal(replay.status, 400);
});

test('registration OTP produces an email- and purpose-bound ticket, then exchanges into the DB-compatible Supabase JWT', async () => {
  await resetDb();
  const email = 'student@example.invalid';
  const requested = await requestOtp(email, 'student.register');
  assert.equal(requested.status, 200);
  const verified = await verifyOtp(email, await capturedCode(email));
  assert.equal(verified.status, 200);
  const proof = await verified.json();
  assert.equal(proof.ok, true);
  assert.equal(proof.verified, true);
  assert.equal(proof.purpose, 'student.register');
  assert.equal(typeof proof.otp_ticket, 'string');

  const nowSeconds = Math.floor(Date.now() / 1000);
  const { publicKey, privateKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
    publicKeyEncoding: { format: 'jwk' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });
  const exchange = createExchangeWorker({
    now: () => nowSeconds,
    fetchImpl: async () => new Response(JSON.stringify({
      keys: [{ ...publicKey, kid: 'miniflare-test-key', alg: 'RS256', use: 'sig' }],
    }), { status: 200, headers: { 'content-type': 'application/json' } }),
  });
  const response = await exchange.fetch(new Request('https://schoolivia-test.invalid/exchange', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      firebase_id_token: makeFirebaseToken({
        uid: 'firebase-miniflare-student',
        email,
        privateKey,
        nowSeconds,
      }),
      otp_ticket: proof.otp_ticket,
    }),
  }), {
    FIREBASE_PROJECT_ID: projectId,
    OTP_PROOF_SECRET: otpProofSecret,
    SUPABASE_JWT_SECRET: supabaseJwtSecret,
  });
  assert.equal(response.status, 200);
  const exchanged = await response.json();
  assert.equal(exchanged.token_type, 'bearer');
  const claims = decodeJwtPayload(exchanged.access_token);
  assert.equal(claims.iss, `https://securetoken.google.com/${projectId}`);
  assert.equal(claims.aud, projectId);
  assert.equal(claims.role, 'authenticated');
  assert.equal(claims.sub, 'firebase-miniflare-student');
  assert.equal(claims.email, email);
  assert.equal(claims.otp_verified, true);
  assert.equal(claims.otp_uid, claims.sub);
  assert.equal(claims.otp_email, email);
  assert.equal(claims.otp_purpose, 'student.register');
  assert.equal(typeof claims.otp_jti, 'string');
  assert.ok(claims.exp <= claims.otp_exp);
});

test('teacher registration purpose is carried through the OTP ticket', async () => {
  await resetDb();
  const email = 'teacher@example.invalid';
  assert.equal((await requestOtp(email, 'teacher.register')).status, 200);
  const response = await verifyOtp(email, await capturedCode(email));
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.purpose, 'teacher.register');
  assert.equal(typeof body.otp_ticket, 'string');
});

test('unsupported registration purpose is rejected before storing an OTP challenge', async () => {
  await resetDb();
  const response = await requestOtp('unknown@example.invalid', 'admin.register');
  assert.equal(response.status, 400);
  assert.equal(await db.prepare('SELECT count(*) AS n FROM otp_challenges').first().then(x => x.n), 0);
});

test('incorrect OTP attempts increment and lock the challenge at the configured limit', async () => {
  await resetDb();
  const email = 'attempts@example.invalid';
  await requestOtp(email, 'student.register');
  for (let i = 0; i < 5; i++) {
    const response = await verifyOtp(email, '000000');
    assert.equal(response.status, 400);
  }
  const locked = await verifyOtp(email, '246810');
  assert.equal(locked.status, 429);
  assert.equal(await db.prepare('SELECT count(*) AS n FROM otp_challenges').first().then(x => x.n), 0);
});

test('expired OTP challenges are deleted and cannot issue a proof ticket', async () => {
  await resetDb();
  const email = 'expired@example.invalid';
  await requestOtp(email, 'student.register');
  await db.prepare('UPDATE otp_challenges SET expires_at = 1 WHERE email = ?').bind(email).run();
  const response = await verifyOtp(email, '246810');
  assert.equal(response.status, 400);
  assert.equal(await db.prepare('SELECT count(*) AS n FROM otp_challenges').first().then(x => x.n), 0);
});

test('two concurrent verification requests consume one OTP challenge exactly once', async () => {
  await resetDb();
  const email = 'race@example.invalid';
  await requestOtp(email, 'student.register');
  const code = await capturedCode(email);
  const results = await Promise.all([verifyOtp(email, code), verifyOtp(email, code)]);
  assert.equal(results.filter(x => x.status === 200).length, 1);
  assert.equal(results.filter(x => x.status !== 200).length, 1);
  assert.equal(await db.prepare('SELECT count(*) AS n FROM otp_challenges').first().then(x => x.n), 0);
});

test('D1 errors fail closed without reporting OTP verification success', async () => {
  await db.prepare('DROP TABLE otp_challenges').run();
  const response = await verifyOtp('unavailable@example.invalid', '246810');
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { ok: false, error: 'OTP service temporarily unavailable' });
});
