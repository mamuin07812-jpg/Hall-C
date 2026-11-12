import assert from 'node:assert/strict';
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { assertConnectionFilesOutsideRepository } from './connection_file_guard.mjs';

const repository = fileURLToPath(new URL('../../../', import.meta.url));
test('connection guard rejects an existing connection file inside the repository', async () => {
  const internalDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '.guard-test-tmp');
  await mkdir(internalDir, { recursive: true });
  const file = path.join(internalDir, 'dummy-connection-file');
  try {
    await writeFile(file, 'synthetic placeholder only');
    assert.throws(() => assertConnectionFilesOutsideRepository([file], repository), /outside the repository/);
  } finally { await rm(internalDir, { recursive: true, force: true }); }
});

test('connection guard accepts an existing connection file outside the repository', async () => {
  const outside = await mkdtemp(path.join(tmpdir(), 'schoolivia-connection-guard-'));
  const file = path.join(outside, 'dummy-connection-file');
  try {
    await writeFile(file, 'synthetic placeholder only');
    assert.doesNotThrow(() => assertConnectionFilesOutsideRepository([file], repository));
  } finally { await rm(outside, { recursive: true, force: true }); }
});
