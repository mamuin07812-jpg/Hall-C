# Approved roster CSV preflight

This is an offline validation step only. It does not upload data or call Supabase.

## Template

Start from `approved_roster_template.csv` and fill exactly these columns, in order:

`university_id,email,full_name,department,stage,hall,enabled`

- `university_id`: official student ID; unique across the file.
- `email`: the student's email used by Firebase Auth; unique after trimming and case normalization.
- `full_name`: official display name from the approved roster.
- `department`: canonical department name, normally `English Language`.
- `stage`: exactly `First Stage`, `Second Stage`, `Third Stage`, or `Fourth Stage`.
- `hall`: A, B, C, or D.
- `enabled`: `true` or `false`.

CSV quoting is supported for names containing commas. The final database importer accepts 1–5000 records per batch.

## Validate locally

From the project root:

```powershell
node .\supabase\firebase_rebuild\otp_proof_test\validate_roster_csv.mjs .\path\to\approved_roster.csv
```

A passing result prints only the row count. A failing result prints line number, field, and error code; it does not echo student names, IDs, or emails.

## Safety boundary

- Keep the roster file private; do not paste student records or credentials into chat.
- This preflight is read-only. It does not convert to JSON, call PostgREST, upload, or change a database.
- Passing validation is not authorization to import. Import must be separately approved and performed only by an authorized Admin through the admin-only RPC, after review of the source roster and the target environment.
