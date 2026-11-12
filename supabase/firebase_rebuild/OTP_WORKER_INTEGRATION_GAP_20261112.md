# Production OTP Worker gap analysis — 2026-11-12

**Inspection only.** The deployed Cloudflare Worker `schoolivia-un-otp-worker` was read through the Cloudflare API. No Worker code, secret, binding, D1 schema, or deployment was changed. Secret values were not read or emitted.

## Observed deployed behavior

- Worker router exposes `POST /request-otp`, `POST /verify-otp`, `POST /forgot-password/request-otp`, `POST /forgot-password/verify-otp`, and `POST /forgot-password/reset-password`.
- `verifyOtp()` accepts only `email` and `code`. It checks the active D1 challenge, expiry, attempt count, and SHA-256 code hash; on success it deletes the challenge and returns only `{ok:true, verified:true}`.
- The deployed source contains no registration proof claims (`otp_uid`, `otp_purpose`, `otp_jti`, `otp_exp`), no signed registration ticket, and no Firebase-ID-token-to-Supabase-JWT exchange route.
- Its `firebaseAccessToken()` helper signs a Google service-account assertion for Firebase account/password-reset operations. It is not a verifier for a client Firebase ID token and must not be reused as one.
- The existing forgot-password routes are separate and must remain unchanged.

## Why this blocks the staged registration RPC

Migration 005 requires a trusted PostgREST JWT with the Firebase project issuer/audience and these OTP claims:

- `otp_verified=true`
- `otp_uid` equal to the Firebase UID in `sub`
- `otp_email` equal to the JWT email
- `otp_purpose` exactly `student.register` or `teacher.register`
- a short-lived `otp_jti` and `otp_exp`

The database atomically consumes `otp_jti` during registration. The current deployed `/verify-otp` response cannot satisfy this contract. A client-supplied `verified:true` is deliberately not accepted by the database.

## Compatible additive protocol proposal (not implemented or deployed)

The captured student flow verifies the email OTP before it creates the Firebase Auth user. Therefore the Worker cannot bind the OTP to a Firebase UID at the moment of the existing OTP verification. The bridge must preserve that ordering rather than pretending the UID already exists.

1. Keep all existing OTP and forgot-password routes operational. For the new registration path, carry an allow-listed purpose (`student.register` or `teacher.register`) with the OTP challenge.
2. After a successful OTP check, issue a short-lived signed email-and-purpose ticket containing a random `jti`. Do not expose the OTP code or any signing secret. Legacy requests that do not opt into registration proof keep the existing response shape.
3. After Firebase Auth creates the user, the client obtains a fresh Firebase ID token and sends it with the ticket to a new exchange route.
4. The exchange route cryptographically verifies the Firebase ID token (signature, `kid`, issuer, audience, expiry, subject, and email), verifies the ticket signature/expiry, and requires exact normalized email and purpose agreement. Only then does it issue a short-lived Supabase-compatible JWT.
5. The issued JWT uses the exact Firebase issuer/audience expected by `schoolivia.jwt_context_ok()`, `role=authenticated`, `sub=<Firebase UID>`, and the OTP claims listed above. Its lifetime is bounded by both the Firebase token and ticket expiries (and the five-minute proof ceiling).
6. The Worker signs with the Supabase JWT signing secret stored as a Worker secret. Never place a Supabase service-role key or signing secret in Flutter. The database consumes `jti` transactionally; replay, wrong purpose, wrong UID/email, and expiry remain denied.
7. Add regression tests for old OTP response compatibility, wrong email, wrong UID, wrong purpose, expired ticket, forged Firebase token, replay, and database outage. Only after these pass in an isolated Worker/D1 test environment should a separately approved production change be considered.

## Unresolved implementation detail

Before writing a D1 migration, inspect only the table definitions and indexes for the deployed OTP challenge schema. Decide whether to add purpose/ticket state to the existing challenge table or use a separate registration-proof table. Do not query or export challenge rows, OTP hashes, user records, or secret values. Any production D1/Worker modification requires separate explicit authorization.

## Test-only exchange prototype added

A standalone Worker draft now exists at `otp_proof_test/otp_proof_exchange_worker_draft.mjs`. It is not connected to the deployed Worker and is not deployed. It implements:

- RSA-SHA256 Firebase ID-token signature verification against the Google Secure Token JWKS endpoint, plus exact project issuer/audience, UID, email, issued-at, and expiry checks.
- HMAC-signed short-lived email/purpose OTP tickets (maximum five minutes), designed to be issued only after the existing OTP challenge has been successfully consumed.
- Exact email binding between Firebase ID token and OTP ticket; allowed registration purposes only.
- A Supabase-compatible HS256 JWT with Firebase issuer/audience, authenticated role, Firebase UID in `sub`, and the required OTP proof claims. Its lifetime is bounded by both source tokens and five minutes.
- No service-role claim/key, no client-provided verification boolean, and no D1 or Supabase writes. The SQL registration RPC remains responsible for atomic one-time `jti` consumption.

Synthetic Node tests generate their own RSA key pair, fake JWKS response, and test-only HMAC secrets. They cover valid exchange, wrong email/purpose, expiry, wrong project, forged/unknown Firebase signing keys, malformed requests, missing secrets, and repeated ticket exchange retaining the same `jti`. GitHub Actions run **43220109370** passed **34/34 static + CSV + exchange tests** and **23/23 native PostgreSQL/PostgREST checks**. This is protocol proof only; it does not exercise the deployed Worker or real Google JWKS network.

## Current boundary

- Candidate SQL migrations and CI are test-only and have passed isolated PostgreSQL/PostgREST checks.
- No deployed OTP Worker, D1 database, Firebase Auth, production Supabase, local Supabase, Flutter, or Admin runtime has been modified.
- PR #7 remains open and unmerged.
