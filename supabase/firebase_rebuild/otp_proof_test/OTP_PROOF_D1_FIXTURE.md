# OTP proof Worker + D1 test fixture

This is a **test-only** Worker fixture. It is not the deployed `schoolivia-un-otp-worker`, is not configured with production bindings, and must never be deployed as-is.

## Files

- `otp_proof_worker_d1_draft.mjs`: Worker-style `/request-otp` and `/verify-otp` implementation, plus the separate Firebase token `/exchange` handler.
- `otp_proof_exchange_worker_draft.mjs`: RSA/JWKS Firebase ID-token verification, OTP ticket verification, and short-lived Supabase JWT issuance.
- `otp_proof_worker_d1_draft.test.mjs`: Miniflare integration tests against a local SQLite-backed D1 binding.
- `otp_challenge_purpose_migration.sql`: additive migration candidate for the existing D1 challenge table.
- `otp_proof_exchange_worker_draft.test.mjs`: isolated crypto/exchange regression tests.

## Local/CI test

The GitHub Actions workflow installs Miniflare temporarily and runs:

```sh
npm install --no-save --package-lock=false miniflare@3
node --test supabase/firebase_rebuild/otp_proof_test/otp_proof_worker_d1_draft.test.mjs
```

Miniflare provisions a disposable local D1 database. The test-only `otp_test_outbox` stores a synthetic code so the test can retrieve what a real email-delivery adapter would send; no real email is sent. The fixed OTP code and HMAC secrets exist only as test bindings.

The D1 test covers legacy response compatibility, student and teacher purpose binding, the full D1 OTP → signed ticket → Firebase ID-token verification → Supabase JWT exchange, invalid purpose, incorrect attempts, expiry, concurrent single-use consumption, and fail-closed database errors.

## D1 schema finding

A read-only metadata inspection of the existing test database `schoolivia-un-otp-state-test-20261111` found that `otp_challenges` currently has these columns:

`id, email, code_hash, expires_at, attempts, max_attempts, created_at, last_sent_at`

Its email/id index exists, but it has no `purpose` column. The test database was not modified. The production OTP database was not queried.

The migration candidate adds a nullable, constrained `purpose` column. Existing challenge rows remain `NULL`, so legacy verification can keep returning exactly `{ok:true,verified:true}`. Only requests explicitly carrying `student.register` or `teacher.register` should receive a registration proof ticket.

## Before any production integration

1. Separately inspect the production D1 table/index metadata only, without reading challenge rows or hashes.
2. Confirm the migration against the exact production schema and take a supported D1 backup.
3. Review the Worker diff so existing forgot-password routes, email delivery, rate limits, expiry, attempt limits, and response shapes remain unchanged.
4. Add the new Worker secrets through Cloudflare's secret-management interface; never expose them to Flutter or Git.
5. Apply the D1 migration and Worker change only after explicit production authorization.
6. Verify real Firebase Secure Token JWKS behavior, token expiry, email binding, proof purpose, and one-time `jti` consumption through the Supabase RPC.

No production resource has been changed by this fixture.
