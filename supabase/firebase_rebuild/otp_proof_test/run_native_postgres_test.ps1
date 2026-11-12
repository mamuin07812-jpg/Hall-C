param(
  [Parameter(Mandatory=$true)][string]$PgServiceFile,
  [Parameter(Mandatory=$true)][string]$PgService,
  [Parameter(Mandatory=$true)][string]$PostgrestExe,
  [Parameter(Mandatory=$true)][string]$PostgrestUriFile,
  [string]$PsqlExe = 'psql',
  [string]$PgDumpExe = 'pg_dump'
)
$ErrorActionPreference = 'Stop'
foreach ($path in @($PgServiceFile, $PostgrestExe, $PostgrestUriFile)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required test file missing: $path" }
}
$env:PGSERVICEFILE = (Resolve-Path -LiteralPath $PgServiceFile).Path
$env:SCHOOLIVIA_TEST_PG_SERVICE = $PgService
$env:SCHOOLIVIA_POSTGREST = (Resolve-Path -LiteralPath $PostgrestExe).Path
$env:SCHOOLIVIA_TEST_POSTGREST_URI_FILE = (Resolve-Path -LiteralPath $PostgrestUriFile).Path
$env:SCHOOLIVIA_PSQL = $PsqlExe
$env:SCHOOLIVIA_PG_DUMP = $PgDumpExe
node (Join-Path $PSScriptRoot 'native_postgres_test.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Native PostgreSQL test runner failed. No connection values are printed.' }
