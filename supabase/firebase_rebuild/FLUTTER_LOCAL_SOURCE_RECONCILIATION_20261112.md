# Flutter registration handoff — local source reconciliation (2026-11-12)

## Why the Flutter RPC patch is not applied yet

The GitHub repository snapshots were checked on `main` and all available app branches. Their `lib/register_page.dart` has one shared `_nameController`, creates the Firebase user before the Firestore write, and sends a Firebase email-verification link. It does not contain the current OTP request/verify flow or the four student name controllers.

The historical local-project capture from `C:\ClassroomHub` instead shows the actual student registration UI has four separate controllers:
- `_firstNameController`
- `_fatherNameController`
- `_grandfatherNameController`
- `_greatGrandfatherNameController`

It also confirms the teacher form has one full-name controller. The local source and GitHub snapshot therefore differ. Do not replace the local registration page with the repository copy, do not pull/reset/checkout the user's working tree, and do not edit the stable UI based on the stale GitHub snapshot.

## Exact next action inside the local Codex workspace

Open Codex with the local project `C:\ClassroomHub` as its workspace and run this task:

1. Read-only inspect `git status --short`, current branch, current HEAD, and local diffs. Do not discard, stash, reset, checkout, or pull.
2. Inspect the actual local versions of:
   - `lib/register_page.dart`
   - `lib/account_gate.dart`
   - any file that implements `/request-otp` and `/verify-otp`
   - Firebase auth/session initialization
   - `pubspec.yaml` dependency versions
3. Map the current student and teacher flow exactly: when OTP is requested/verified, when Firebase Auth user is created, where the Firebase ID token is refreshed, and which Firestore documents/keys are written.
4. Confirm the four student name components and keep `greatGrandfatherName` separate from `familyName`. Do not invent a family-name input.
5. Confirm the current email-verified behavior. Do not change Firebase Auth, OTP endpoints, password reset, login, logout, or email verification.
6. Inspect whether the local project already contains Supabase URL/key configuration, but do not print, copy, or modify secret values. Do not inspect `.env` contents or any credential file.
7. Produce a concise source map with exact file/line references and a proposed minimal integration diff. Do not modify Flutter, Admin, Firebase, Workers, or database files in this inspection pass.

## After local source reconciliation

Only then prepare a minimal integration that:
- uses the existing Firebase ID token;
- sends the signed OTP ticket to the exchange endpoint;
- stores the short-lived Supabase JWT in memory only;
- calls `schoolivia.register_student` or `schoolivia.register_teacher` with the exact existing UI fields;
- keeps teacher status pending;
- completes student academic profile using the existing gender/stage/hall controls;
- preserves current Firestore fallback and current Firebase login/session behavior until an independently approved cutover.

The exchange Worker/D1 migration is still a test-only draft. Do not call a production exchange endpoint or switch Flutter to Supabase until the production Worker/D1 integration is separately approved and deployed.
