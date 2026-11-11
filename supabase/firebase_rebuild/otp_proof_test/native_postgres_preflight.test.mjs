import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const runner = fileURLToPath(new URL('./native_postgres_test.mjs', import.meta.url));

test('native runner rejects a protected service target before invoking database tools', async () => {
  const directory = await mkdtemp(path.join(tmpdir(), 'schoolivia-pg-preflight-'));
  try {
    const serviceFile = path.join(directory, 'pg_service.conf');
    const uriFile = path.join(directory, 'postgrest-uri');
    await writeFile(serviceFile, '[schoolivia_ci]\nhost=protected.example.invalid\nport=18432\ndbname=schoolivia_test_fake\nuser=postgres\n');
    await writeFile(uriFile, 'postgres://authenticator:test@127.0.0.1:18432/schoolivia_test_fake');
    const result = spawnSync(process.execPath, [runner], {
      encoding: 'utf8',
      env: {
        ...process.env,
        SCHOOLIVIA_TEST_PG_SERVICE: 'schoolivia_ci',
        PGSERVICEFILE: serviceFile,
        SCHOOLIVIA_POSTGREST: path.join(directory, 'nonexistent-postgrest'),
        SCHOOLIVIA_TEST_POSTGREST_URI_FILE: uriFile,
      },
      timeout: 10_000,
    });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /PostgreSQL target must be loopback/);
    assert.doesNotMatch(result.stderr, /psql failed|pg_dump failed/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
