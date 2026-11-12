# Schoolivia UN resume checkpoint — 2026-11-12

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