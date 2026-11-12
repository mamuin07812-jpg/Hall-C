# Schoolivia UN resume checkpoint — 2026-11-12

## Confirmed repository state

- Current branch: `fix/preparation-hall-targeting-review`, tracking `origin/fix/preparation-hall-targeting-review`.
- Latest commit: `e9e9a67` (`Include migration inputs for native PostgreSQL CI`), preceded by `2881d59` (`Add isolated native PostgreSQL migration CI`). No new commit, branch, PR, or merge was created during this continuation.
- The working tree already contained extensive application, configuration, test, backup, and diagnostic artifacts. They are preserved as found; no cleanup, reset, or overwrite was performed.
- Existing successful results in `EXECUTION_STATUS_20261111.md` and its referenced logs remain accepted. No successful suite was rerun.
- The GitHub Actions workflow exists locally, but its remote run history could not be read: `gh` is unavailable, and the GitHub API endpoint was inaccessible from the available web tool. Therefore no CI run is claimed as passed or failed.

## Last confirmed incomplete work

The native PostgreSQL 17.6/Supabase migration gate remains the first unfinished technical task. On 2026-11-12, local uncommitted edits were present in:

- `.github/workflows/schoolivia-native-migrations.yml`: use the Supabase image's `supabase_admin` bootstrap role, explicitly create the run-specific test database, create connection files in the job, and use the PostgreSQL 17 `pg_dump` binary.
- `otp_proof_test/native_postgres_test.mjs`: redact diagnostic secrets on dump failure and add checks for private-schema visibility, RPC contracts, and registration-field mapping.

These edits were discovered in the working tree and preserved. They have not been committed or validated by a new test run in this continuation. Continue by reviewing these exact diffs and, when a qualified disposable PostgreSQL 17.6 runner is available, run the existing native CI job once. Do not target existing local/WSL Supabase services or protected databases.

## Safety blockers and next continuation

- No native PostgreSQL or Docker runtime is available on Windows; the prior status records WSL as stopped. Do not start or alter it as a shortcut.
- The deployed OTP Worker/D1 provenance and disposable remote clone remain separate blocked gates. The existing status describes the absence of authenticated Cloudflare read-only access. Do not contact production services or infer deployed compatibility from the local test derivative.
- No migration, backup, database, container, application service, Firebase resource, Worker, or production service was created, altered, or deployed in this continuation.
- Next action: obtain/read the native PostgreSQL CI result through an available authenticated GitHub Actions interface; if absent, use the existing workflow on the current PR/branch once. Preserve this branch and PR. Record the result and any narrowly scoped fix in a new dated checkpoint before proceeding.

## CI failure 43175741765 follow-up

- The native runner's Firestore signup-key mapping check was reported failing because it expected keys such as `firstName`, `fatherName`, `grandfatherName`, `emailVerified`, `gender`, `stage`, and `group` that are not part of the requested current signup mapping contract. The mapping assertion has been narrowed to the twelve explicitly confirmed fields: `uid`, `name`, `email`, `studentId`, `department`, `profileCompleted`, `role`, `createdAt`, `updatedAt`, `employeeId`, `specialization`, and `status`, with their typed Schoolivia targets.
- Integration gap confirmed by source review: `lib/register_page.dart` currently writes registration data to Firestore and does not call a Supabase RPC. The UI captures a single full name, while candidate `register_student` requires four separate name arguments. This is a real integration-contract mismatch requiring a separate design/implementation task. This correction does not bind the application to Supabase and does not change Flutter, Firestore, migrations, or RPC signatures.
- For this correction, run only local Node syntax/static checks relevant to the native runner and then the new workflow on PR #7. Do not repeat previously successful suites. The result of run 43175741765 remains a known failure; the result for the follow-up run must be recorded here once observed.

## PR #7 CI correction follow-up

- PR #7 is headed by `fix/native-postgres-runner-temp-20261112`. Commit `5ba996c` was initially pushed to the workspace's active branch `fix/preparation-hall-targeting-review`, which is not PR #7; its Actions run `43207165924` completed without jobs. The requested correction is therefore being applied directly atop the existing PR #7 head, without creating a branch.
- The native runner mapping assertion now contains exactly the twelve specified Firestore profile fields and their PostgreSQL column/type mappings.
- `register_page.dart` currently writes to Firestore and does not call a Supabase RPC. The student UI collects one full name, whereas `register_student` takes four name arguments. This is a real integration mismatch for separate handling; this patch does not bind Flutter to Supabase or change its fields, migrations, or RPC signatures.
- Latest attempted PR validation must be checked by commit SHA. Run 43175741765 was the known source failure. Do not rerun unrelated successful suites.