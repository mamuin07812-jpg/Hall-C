# Schoolivia UN resume checkpoint — 2026-11-12

## OTP Worker exchange prototype — test-only (2026-11-12)

- Read-only inspection of the deployed `schoolivia-un-otp-worker` source confirmed `/verify-otp` accepts only email/code, consumes the D1 challenge, and returns `{ok:true,verified:true}`. Its router has no registration proof or Firebase-ID-token exchange endpoint. No Worker code, secret, binding, D1 schema/data, or deployment was changed.
- Added `otp_proof_test/otp_proof_exchange_worker_draft.mjs`, an isolated Cloudflare Worker-compatible prototype: RSA-SHA256 Firebase ID-token verification against JWKS, email/purpose-bound HMAC OTP ticket verification, and short-lived Supabase HS256 JWT issuance with the exact Firebase issuer/audience, authenticated role, Firebase UID, and OTP claims expected by the candidate SQL.
- The ticket issuer helper is designed to be called only after successful OTP verification. The prototype intentionally has no D1 binding; the database remains the one-time `jti` consumption boundary. It is not wired to the deployed OTP Worker and is not deployed.
- Added 11 synthetic tests with generated RSA keys and test-only secrets. GitHub Actions run **43220109370** passed **34/34 static + CSV + exchange tests** and **23/23 native PostgreSQL 17/PostgREST 14.18 checks**. The temporary DB was removed. This does not yet validate real Google JWKS connectivity or a real Worker/D1 integration.
- Next safe implementation step: adapt the proof-ticket issuance into a separate test Worker/D1 fixture and exercise the current OTP flow end-to-end, preserving the legacy response for existing clients. Production changes still require separate explicit authorization.


## Academic completion + roster preflight — CI PASS (2026-11-12)

- Added four native PostgREST checks for `complete_student_registration`: correct gender/stage/hall succeeds; mismatched stage, mismatched hall, and unsupported gender are rejected without marking the profile complete. PostgREST returns HTTP 204 for the successful void RPC.
- Teacher specialization is free text in the captured UI. Migration 005 maps the 10 known English/Arabic labels to canonical English and rejects unknown values before consuming OTP proof.
- Added blank CSV template `supabase/firebase_rebuild/approved_roster_template.csv`, offline validator `otp_proof_test/validate_roster_csv.mjs`, seven validator tests, and usage/safety instructions in `ROSTER_IMPORT_PREFLIGHT.md`. No records are uploaded or imported.
- GitHub Actions run **43218575411** passed on commit `6fea180cf9b96b405e5c7f05cefe24be43dc1cf4`: 23 static/CSV tests and 23 native PostgreSQL 17 + PostgREST 14.18 HTTP checks. Pre-migration disposable DB dump SHA-256: `1a27d355ebdab1ceb820d5fb5ed284f65885e58d1b12c46a85e38ddcea6ad866`. Disposable DB/container were removed successfully.
- No local/production Supabase, Firebase, OTP Worker, Flutter, or Admin runtime was changed. PR #7 remains open/unmerged.


## Registration contract and roster-import tooling follow-up — 2026-11-12

- Corrected the academic-completion compatibility review: the captured `register_page.dart` signup completion explicitly requires and writes gender, stage, and hall/group, so these values match `complete_student_registration(p_gender,p_stage,p_hall)`. The separate `account_gate.dart` fallback/profile path is distinct and still has no Supabase RPC; the test name/report now identify it accurately.
- Teacher registration specialization is free text in the captured app. Candidate migration 005 now normalizes the 10 established subject names in English and their known Arabic aliases to canonical English; unknown values are rejected before OTP proof consumption. Added static contract and native PostgREST tests for Arabic normalization and unknown-value rejection.
- Added a blank seven-column CSV template at `supabase/firebase_rebuild/approved_roster_template.csv` and an offline validator at `otp_proof_test/validate_roster_csv.mjs`. It checks exact headers, required fields, email format, duplicate IDs/emails, stage, hall, enabled boolean, CSV quoting, and the 5,000-row batch limit. It prints validation errors without echoing student data and does not upload or import anything.
- Added seven synthetic validator tests and included them in the PR's native migration workflow. Latest workflow run **43217802990** is queued; prior run 43217555776 was cancelled by the subsequent branch update, so do not treat it as a test failure or pass.
- No Flutter, Admin, Firebase, OTP Worker, local Supabase, or production data/service changes. PR #7 remains open/unmerged.


## Required student-name validation — CI PASS (2026-11-12)

- Final candidate migration `005_otp_proof_registration.sql` now rejects a blank or whitespace-only value in any of the four student name components: first, father, grandfather, great-grandfather.
- Added a static registration-contract assertion and native PostgREST HTTP cases that omit each field in turn. Each case is rejected, creates no profile, and does not consume the OTP proof `jti`.
- GitHub Actions run **43216763874** passed on commit `18a9c237fb56b1ab87c67849da89ffec4891dd0f`.
- Results: 15/15 static guard/contract tests; 17/17 disposable PostgreSQL 17 + PostgREST 14.18 HTTP checks. The temporary database backup SHA-256 was `54c888d9c68a6bd9a1be0e053ed584efbb2c4c5519c550c75114498d5c498317`; temporary PostgreSQL container was removed successfully.
- No migration was applied to the local self-hosted Supabase, production Supabase, Firebase, Flutter, or Admin. PR #7 remains open and unmerged.


## Registration source located — 2026-11-12 15:17 Iraq time

- Searched prior project terminal captures in the user's Library and found an actual `C:\\ClassroomHub\\lib\\register_page.dart` excerpt. At lines 370–399 it uses four student controllers: `_firstNameController`, `_fatherNameController`, `_grandfatherNameController`, `_greatGrandfatherNameController`; joins them into `name`; and writes the four individual Firestore keys. At lines 498–520 the teacher registration uses one `_nameController` full name.
- The captured student registration also wrote the fourth field into both `greatGrandfatherName` and `familyName`. The captured `account_gate.dart` profile completion wrote the same `_familyName` value into both keys. This is a legacy duplicate mapping, not proof of a separate family-name input. User confirmed the fourth registration field means great-grandfather's name.
- GitHub `main` and PR #7 source snapshots still differ (single shared full-name field); the prior local capture is stronger evidence for the app version user described. We did not modify Flutter or Firebase. Compatibility report updated to record the source evidence and legacy duplicate.
- Candidate SQL mappings remain corrected so `p_great_grandfather_name` writes only `great_grandfather_name`; `family_name` remains separate. Native PostgreSQL CI already passed after this correction.


## Native PostgreSQL CI result — 2026-11-12 15:14 Iraq time

- Run `43215900715` completed successfully against the PR #7 merge commit `6582ce6542a7884d22ff6d3056435d364d180335`.
- Registration contract and connection/migration guard suite: 14/14 passed, including the new assertion that great-grandfather name is stored separately from family name.
- Disposable native Supabase PostgreSQL 17 + PostgREST 14.18 integration: 16/16 passed. Covered schema exposure, RPC signatures, Firestore key mapping, roster-bound student registration, idempotent retry, rejection cases, signed OTP proof purpose/expiry/one-time use, rollback/retry, concurrency, teacher pending status, no self-approval, student/teacher RLS isolation, and expired sessions.
- Ephemeral DB pre-migration backup hash: `45815675722dfc10f78f65a0d6b4a39c6610bd5a118c87263c9579edf05d9902`. Temporary PostgreSQL container was removed by the workflow.
- PR #7 remains OPEN, unmerged, and mergeable. Do not merge without explicit user instruction.
- Source discrepancy independently rechecked on `main`: `lib/register_page.dart` has one shared `_nameController`/Full Name field for student and teacher. User explicitly confirms their student form has four fields and teacher form one. Treat the inspected main/PR source as stale or not the live source; no Flutter changes made. Need locate the correct student registration source/version before integration.
- No migration applied to any user DB; no Flutter/Admin/Firebase/OTP Worker/production or protected local service changed.


## Latest continuation update — 2026-11-12 15:11 Iraq time

- User confirmed student registration captures four separate fields: first name, father's name, grandfather's name, and great-grandfather's name. The fourth field is specifically the great-grandfather's name, not family name. Teacher registration remains one full-name field.
- Corrected candidate registration inserts in migrations 001, 003, 004, and 005: `p_great_grandfather_name` now populates only `profiles.great_grandfather_name`; `profiles.family_name` remains separate and unset by registration.
- Updated `REGISTRATION_COMPATIBILITY_20261112.md` and the contract test to reflect the confirmed semantics and guard against the previous duplicate mapping.
- Important source discrepancy remains: the `lib/register_page.dart` file inspected on this PR branch still shows a single shared full-name field for student and teacher, unlike the user's description of the current student form. Do not edit Flutter based on this snapshot; reconcile the correct source/version before integration.
- These are candidate SQL/test/documentation changes on the existing PR #7 branch only. No migration was applied; no Flutter/Admin/Firebase/Worker/local production-like DB was changed. PR #7 remains open and unmerged. The latest SQL/test changes now require a fresh disposable native PostgreSQL CI run.


## Current verified GitHub state (authoritative)

- Repository: `mamuin07812-jpg/Hall-C`.
- Active continuation branch for this task: `fix/native-postgres-runner-temp-20261112`.
- PR #7 is OPEN and NOT MERGED; head commit: `207ec266707d7bd81bb89a7b34add2d44c76c03c`.
- The native PostgreSQL/PostgREST workflow run `43214017213` completed successfully on commit `63522e4cbd74d0e71b97d2558e2ee266eda25d0d`. It included the new registration contract test. The later `207ec26` commit only updates this checkpoint, so it does not require another CI run.
- Do not treat the earlier repository-state and CI-access statements below as current: they are preserved historical notes from the initial checkpoint and were superseded by the PR #7 verification sections further down.
- No PR merge, production deployment, database migration against a live service, or Flutter/Admin/Firebase behavior change was performed.

## Current registration contract findings

- `REGISTRATION_COMPATIBILITY_20261112.md` documents the read-only comparison of Flutter/Admin and migrations 001–005.
- `otp_proof_test/registration_contract.test.mjs` adds six static contract tests. Local result: 6/6; the PR workflow containing the new test passed in run `43214017213`.
- Current student and teacher signup remain Firebase Auth + Firestore. Neither calls Supabase RPC or exchanges an OTP proof for a Supabase session.
- Student UI captures one full name and student ID; candidate RPC requires four name components plus student ID. Do not split a full name heuristically.
- Final approved-roster import contract is migration 004: JSON rows with `university_id`, `email`, `full_name`, `department`, `stage`, `hall`, `enabled`; Admin currently has no roster import path.
- Student setup currently captures stage/group only; candidate completion RPC also requires gender and exact roster stage/hall match.
- Teacher inputs are name, employee ID, and free-text specialization; SQL has a fixed specialization allow-list.
- Migration 005 requires signed OTP proof claims bound to Firebase UID, email, purpose, expiry, and one-time JTI consumption. Firebase email-link verification is not equivalent.
- The duplicate assignment of `p_great_grandfather_name` to both `great_grandfather_name` and `family_name` remains unresolved. Do not change it without an explicit data-model decision.
- These are compatibility findings only; no application integration or production readiness is claimed.

## Safety and continuation constraints

- Keep PR #7 open; do not merge it without explicit instruction.
- Do not modify Flutter, Admin, Firebase Auth/Firestore/FCM, OTP Worker/D1, production Supabase, or protected local databases as part of contract review.
- Do not apply migrations to existing WSL/local Supabase services. Native PostgreSQL validation must remain disposable and isolated.
- Do not rerun successful suites without a code/test change that requires it.
- Any future app integration needs an approved design for student name semantics, roster import format/authorization, teacher specialization values, gender collection, and signed OTP-proof issuance/consumption. Keep the existing Firebase login/OTP behavior intact until a separately approved migration plan exists.

## Historical checkpoint notes

The sections below preserve earlier diagnostic history. Their branch names, CI status, and "next action" statements describe the state at the time they were written; they are not the current state above.

## CI failure 43175741765 follow-up

- The native runner's Firestore signup-key mapping check was reported failing because it expected keys such as `firstName`, `fatherName`, `grandfatherName`, `emailVerified`, `gender`, `stage`, and `group` that are not part of the requested current signup mapping contract. The mapping assertion has been narrowed to the twelve explicitly confirmed fields: `uid`, `name`, `email`, `studentId`, `department`, `profileCompleted`, `role`, `createdAt`, `updatedAt`, `employeeId`, `specialization`, and `status`, with their typed Schoolivia targets.
- Integration gap confirmed by source review: `lib/register_page.dart` currently writes registration data to Firestore and does not call a Supabase RPC. The UI captures a single full name, while candidate `register_student` requires four separate name arguments. This is a real integration-contract mismatch requiring a separate design/implementation task. This correction does not bind the application to Supabase and does not change Flutter, Firestore, migrations, or RPC signatures.
- For this correction, run only local Node syntax/static checks relevant to the native runner and then the new workflow on PR #7. Do not repeat previously successful suites. The result of run 43175741765 remains a known failure; the result for the follow-up run must be recorded here once observed.

## PR #7 CI correction follow-up

- PR #7 is headed by `fix/native-postgres-runner-temp-20261112`. Commit `5ba996c` was initially pushed to the workspace's active branch `fix/preparation-hall-targeting-review`, which is not PR #7; its Actions run `43207165924` completed without jobs. The requested correction is therefore being applied directly atop the existing PR #7 head, without creating a branch.
- The native runner mapping assertion now contains exactly the twelve specified Firestore profile fields and their PostgreSQL column/type mappings.
- `register_page.dart` currently writes to Firestore and does not call a Supabase RPC. The student UI collects one full name, whereas `register_student` takes four name arguments. This is a real integration mismatch for separate handling; this patch does not bind Flutter to Supabase or change its fields, migrations, or RPC signatures.
- Latest attempted PR validation must be checked by commit SHA. Run 43175741765 was the known source failure. Do not rerun unrelated successful suites.
## Verified PR #7 result

- Commit `8581975aa4af891800395bacdda7f995946c1567` is on the existing PR #7 head branch `fix/native-postgres-runner-temp-20261112`.
- GitHub Actions run `43208244691` completed with `success` for `Disposable Supabase PostgreSQL 17 migrations 001–005`.
- The runner installed PostgreSQL 17 client tools, started only its disposable Supabase PostgreSQL 17 container, provisioned synthetic PostgREST roles, downloaded pinned PostgREST 14.18, and passed `Execute native migrations and PostgreSQL/PostgREST checks`; its disposable container cleanup also passed.
- No migrations were applied to a protected database. No Flutter/Admin changes, production deployment, or merge occurred.
## Registration contract review progress

- Added `REGISTRATION_COMPATIBILITY_20261112.md` with a field-by-field matrix for Flutter/Admin, Firebase Auth/Firestore, and migrations 001–005; it records the effective roster import contract and integration blockers.
- Added `otp_proof_test/registration_contract.test.mjs` with six independent static contract tests covering RPC argument names/order/types/returns, final JSON import fields and validation, actual Firestore signup keys and verification flow, academic completion shape/roster matching, Admin roster-import absence, and the unresolved great-grandfather/family-name overlap.
- The new local test passed 6/6, and `node --check` passed. These are new checks; no previous successful suite was rerun.
- The test is wired into the native PostgreSQL workflow and its path filter. This intentionally makes a fresh PR workflow run necessary to verify the newly added check; no SQL migration or app behavior was changed. CI result is pending for the next PR head.
## Registration contract CI result

- PR #7 commit `63522e4cbd74d0e71b97d2558e2ee266eda25d0d` completed GitHub Actions run `43214017213` with `success`.
- The workflow ran the new `registration_contract.test.mjs` in its Node test command, followed by the native PostgreSQL 17 migrations and PostgREST integration checks; the overall job passed.
- The contract suite passed locally 6/6. No app or migration code changed. The green CI run is associated with `63522e4`; subsequent checkpoint-only documentation does not need another run.
- Main remaining blockers are documented in `REGISTRATION_COMPATIBILITY_20261112.md`: no Supabase bridge/proof in Flutter, no approved-roster import UI, the student name/gender contract gaps, roster-dependent academic matching, and the unresolved surname-slot semantics.