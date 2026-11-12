// Native PostgreSQL/PostgREST test runner. Uses only a user-provisioned,
// disposable loopback database; credentials are read from pg service/config files.
import assert from 'node:assert/strict';
import { createHash, generateKeyPairSync, randomBytes, sign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { assertConnectionFilesOutsideRepository } from './connection_file_guard.mjs';
import { assertDisposablePostgrestUri, assertDisposableTarget, assertExpectedServerAddress, parsePgServiceTarget } from './native_connection_guard.mjs';
import { rewriteFirebaseProjectIdForNativeTest } from './native_test_migrations.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const service = process.env.SCHOOLIVIA_TEST_PG_SERVICE;
const serviceFile = process.env.PGSERVICEFILE;
const psql = process.env.SCHOOLIVIA_PSQL ?? 'psql';
const pgDump = process.env.SCHOOLIVIA_PG_DUMP ?? 'pg_dump';
const postgrestBin = process.env.SCHOOLIVIA_POSTGREST;
const dbUriFile = process.env.SCHOOLIVIA_TEST_POSTGREST_URI_FILE;
const expectedServerAddress = process.env.SCHOOLIVIA_EXPECTED_PG_SERVER_ADDRESS;
const port = Number(process.env.SCHOOLIVIA_TEST_POSTGREST_PORT ?? '18131');
// Synthetic identifier; migration SQL is rewritten to this value in a temp directory.
const projectId = 'schoolivia-native-test';

function need(value, label) { assert.ok(value, `${label} is required`); }
need(service, 'SCHOOLIVIA_TEST_PG_SERVICE');
need(serviceFile, 'PGSERVICEFILE');
need(postgrestBin, 'SCHOOLIVIA_POSTGREST');
need(dbUriFile, 'SCHOOLIVIA_TEST_POSTGREST_URI_FILE');
assert.ok(Number.isInteger(port) && port >= 18000 && port <= 18999, 'test PostgREST port must be in 18000-18999');
assertConnectionFilesOutsideRepository([serviceFile, dbUriFile], root);
// Refuse unsafe coordinates before invoking psql, pg_dump, or PostgREST.
const serviceTarget = parsePgServiceTarget(readFileSync(serviceFile, 'utf8'), service);
assertDisposableTarget({ host: serviceTarget.host, port: serviceTarget.port, database: serviceTarget.dbname });
const dbUri = readFileSync(dbUriFile, 'utf8').trim();
const parsed = assertDisposablePostgrestUri(dbUri);

const env = { ...process.env, PGSERVICEFILE: serviceFile, PGSERVICE: service, PGCONNECT_TIMEOUT: '5' };
function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: 'utf8', windowsHide: true, env, ...options });
  if (result.status !== 0) throw new Error(`${path.basename(command)} failed (exit ${result.status}); output suppressed to avoid credential leakage`);
  return result.stdout.trim();
}
function sql(query) { return run(psql, ['-X', '-v', 'ON_ERROR_STOP=1', '-At', '-c', query]); }
function secretFreeFileHash(file) { return createHash('sha256').update(readFileSync(file)).digest('hex'); }

const database = sql('select current_database()');
const serverPort = Number(sql("select current_setting('port')"));
const serverAddress = sql("select coalesce(inet_server_addr()::text,'')");
assert.match(database, /^schoolivia_test_[a-z0-9_]+$/, 'database name must begin schoolivia_test_');
assert.notEqual(serverPort, 5432, 'port 5432 is prohibited');
assertExpectedServerAddress(serverAddress, expectedServerAddress);
assert.equal(sql("select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('schoolivia','schoolivia_internal','schoolivia_reconciliation') and c.relkind in ('r','p','v','m','S')"), '0', 'candidate schemas must be empty');
assert.equal(sql("select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname not in ('pg_catalog','information_schema','extensions') and c.relkind in ('r','p','v','m','S')"), '0', 'database must be empty of user relations before test setup');
assert.equal(sql("select count(*) from pg_available_extensions where name='pgcrypto'"), '1', 'PostgreSQL installation must provide the pgcrypto extension');
const roles = sql("select count(*) from pg_roles where rolname in ('anon','authenticated','service_role','authenticator')");
assert.equal(roles, '4', 'isolated PostgreSQL cluster must already contain required test roles');

assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(parsed.hostname), 'PostgREST database URI must be loopback');
assert.equal(decodeURIComponent(parsed.pathname.slice(1)), database, 'PostgREST and psql must target the same test database');
assert.equal(Number(parsed.port), serverPort, 'PostgREST and psql must target the same PostgreSQL port');
assert.equal(decodeURIComponent(parsed.username), 'authenticator', 'PostgREST must connect as authenticator');

const backupDir = await mkdtemp(path.join(tmpdir(), 'schoolivia-native-pre-migration-'));
const dumpFile = path.join(backupDir, `${database}.dump`);
const dumpResult = spawnSync(pgDump, ['--format=custom', '--file', dumpFile], { encoding: 'utf8', windowsHide: true, env });
if (dumpResult.status !== 0) {
  let diagnostic = `${dumpResult.stderr ?? ''}${dumpResult.stdout ?? ''}`.trim();
  for (const secret of [serviceTarget.password, parsed.password, process.env.POSTGRES_PASSWORD, process.env.POSTGREST_TEST_PASSWORD]) {
    if (secret) diagnostic = diagnostic.replaceAll(secret, '[REDACTED]');
  }
  diagnostic = diagnostic.slice(0, 1000);
  throw new Error(`pg_dump failed (exit ${dumpResult.status}); ${diagnostic || 'no diagnostic output'}`);
}
const backupHash = secretFreeFileHash(dumpFile);
assert.equal(secretFreeFileHash(dumpFile), backupHash, 'pre-change dump checksum verification failed');
await rm(backupDir, { recursive: true, force: true });

// Minimal Supabase Storage fixture used by the test-only Schoolivia migrations.
sql(`create schema if not exists extensions;
create schema storage;
create table storage.buckets(id text primary key,name text not null,public boolean default false,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text not null,name text not null,owner_id text);
alter table storage.objects enable row level security;
create function storage.foldername(text) returns text[] language sql immutable as $$ select string_to_array(trim(both '/' from $1), '/') $$;`);

const testMigrationDir = await mkdtemp(path.join(tmpdir(), 'schoolivia-native-migrations-'));
try {
  for (const file of ['001_schoolivia.sql', '002_schoolivia_access_hardening.sql', '003_app_integration_idempotent_roster.sql', '004_verified_roster_email_binding.sql', '005_otp_proof_registration.sql']) {
    const source = await readFile(path.join(root, file), 'utf8');
    const testSql = file === '001_schoolivia.sql' ? rewriteFirebaseProjectIdForNativeTest(source, projectId) : source;
    await writeFile(path.join(testMigrationDir, file), testSql, { flag: 'wx' });
    run(psql, ['-X', '-v', 'ON_ERROR_STOP=1', '-f', path.join(testMigrationDir, file)]);
  }
} catch (error) {
  await rm(testMigrationDir, { recursive: true, force: true });
  throw error;
}

assert.equal(sql("select count(*) from pg_extension e join pg_namespace n on n.oid=e.extnamespace where e.extname='pgcrypto' and n.nspname='extensions'"), '1', 'migration must install pgcrypto into the Supabase extensions schema');
assert.ok(Number(sql("select count(*) from pg_class where relnamespace='schoolivia'::regnamespace and relkind in ('r','p') and relrowsecurity")) >= 14, 'all candidate application tables must have RLS enabled');
assert.ok(Number(sql("select count(*) from pg_policies where schemaname='schoolivia'")) >= 39, 'candidate RLS policy set is incomplete');
assert.equal(sql("select data_type from information_schema.columns where table_schema='schoolivia_internal' and table_name='otp_proof_uses' and column_name='jti'"), 'text', 'replay key must preserve opaque text jti values');
assert.equal(sql("select count(*) from pg_indexes where schemaname='schoolivia_internal' and tablename='otp_proof_uses' and indexdef ilike '%UNIQUE%'"), '1', 'replay ledger must have a unique jti key');
assert.equal(sql("select bool_and(not has_schema_privilege(rolname,'schoolivia_internal','USAGE')) from pg_roles where rolname in ('anon','authenticated','service_role')"), 't', 'API roles must not have usage on the private schema');

const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const jwk = { ...publicKey.export({ format: 'jwk' }), alg: 'ES256', use: 'sig', kid: 'schoolivia-native-test' };
const pgrstEnv = {
  ...env,
  PGRST_DB_URI: `@${dbUriFile}`,
  PGRST_DB_SCHEMAS: 'schoolivia',
  PGRST_DB_ANON_ROLE: 'anon',
  PGRST_DB_EXTRA_SEARCH_PATH: 'public,extensions',
  PGRST_DB_USE_LEGACY_GUCS: 'false',
  PGRST_JWT_SECRET: JSON.stringify({ keys: [jwk] }),
  PGRST_JWT_AUD: projectId,
  PGRST_SERVER_HOST: '127.0.0.1',
  PGRST_SERVER_PORT: String(port),
};
let server;
let checks = 0;
async function check(label, fn) { await fn(); checks++; process.stdout.write(`PASS ${label}\n`); }
function token(uid, email, { purpose, jti = randomBytes(20).toString('base64url'), exp = Math.floor(Date.now() / 1000) + 180, otpExp = exp } = {}) {
  const iat = Math.floor(Date.now() / 1000);
  const header = Buffer.from(JSON.stringify({ alg: 'ES256', typ: 'JWT', kid: jwk.kid })).toString('base64url');
  const claims = { iss: `https://securetoken.google.com/${projectId}`, aud: projectId, sub: uid, role: 'authenticated', iat, exp, auth_time: iat - 2, email, email_verified: false,
    ...(purpose ? { otp_verified: true, otp_uid: uid, otp_email: email, otp_purpose: purpose, otp_jti: jti, otp_exp: otpExp } : {}) };
  const payload = Buffer.from(JSON.stringify(claims)).toString('base64url');
  const input = `${header}.${payload}`;
  return `${input}.${sign('sha256', Buffer.from(input), { key: privateKey, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
}
async function http(route, { jwt, method = 'GET', body } = {}) {
  return fetch(`http://127.0.0.1:${port}${route}`, { method, headers: { ...(jwt ? { authorization: `Bearer ${jwt}` } : {}), ...(body ? { 'content-type': 'application/json' } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(5000) });
}
async function waitReady() {
  const until = Date.now() + 15000;
  while (Date.now() < until) {
    try { const response = await fetch(`http://127.0.0.1:${port}/`, { signal: AbortSignal.timeout(500) }); if (response.ok) return; } catch { /* startup */ }
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  throw new Error('isolated PostgREST did not start; output suppressed');
}
try {
  await sql("insert into schoolivia.approved_students(university_id,email,full_name,department,stage,hall,enabled) values ('NATIVE-001','student-native@example.invalid','Synthetic Student','English Language','First Stage','A',true),('NATIVE-002','student-two-native@example.invalid','Synthetic Student Two','English Language','First Stage','B',true),('NATIVE-003','student-replay-one@example.invalid','Synthetic Replay One','English Language','First Stage','C',true),('NATIVE-004','student-replay-two@example.invalid','Synthetic Replay Two','English Language','First Stage','D',true),('NATIVE-005','student-completion-stage@example.invalid','Synthetic Completion Stage','English Language','First Stage','A',true),('NATIVE-006','student-completion-hall@example.invalid','Synthetic Completion Hall','English Language','Second Stage','D',true),('NATIVE-007','student-completion-gender@example.invalid','Synthetic Completion Gender','English Language','Third Stage','C',true)");
  server = spawn(postgrestBin, [], { env: pgrstEnv, stdio: 'ignore', windowsHide: true });
  await waitReady();
  const studentJwt = token('native-student-uid', 'student-native@example.invalid', { purpose: 'student.register' });
  const teacherJwt = token('native-teacher-uid', 'teacher-native@example.invalid', { purpose: 'teacher.register' });
  await check('PostgREST exposes schoolivia while keeping the OTP schema private', async () => {
    assert.deepEqual(pgrstEnv.PGRST_DB_SCHEMAS.split(',').map(value => value.trim()), ['schoolivia']);
    const exposed = await http('/rpc/register_student', { method: 'POST', jwt: studentJwt, body: { p_first_name: 'Synthetic', p_father_name: 'Native', p_grandfather_name: 'Test', p_great_grandfather_name: 'User', p_student_id: 'NATIVE-001' } });
    assert.equal(exposed.status, 200, `schoolivia RPC route is not exposed or has an unexpected signature: ${exposed.status}`);
    const privateLedger = await http('/otp_proof_uses?select=jti', { jwt: studentJwt });
    assert.equal(privateLedger.status, 404, 'internal OTP ledger must not be reachable through PostgREST');
  });
  await check('candidate RPC names, argument types, and result types remain stable', async () => {
    const signatures = [
      ["schoolivia.register_student(text,text,text,text,text)", 'p_first_name text, p_father_name text, p_grandfather_name text, p_great_grandfather_name text, p_student_id text|uuid'],
      ["schoolivia.register_teacher(text,text,text)", 'p_name text, p_employee_id text, p_specialization text|uuid'],
      ["schoolivia.complete_student_registration(text,text,text)", 'p_gender text, p_stage text, p_hall text|void'],
      ["schoolivia.import_approved_students(jsonb)", 'p_rows jsonb|jsonb'],
    ];
    for (const [signature, expected] of signatures) {
      assert.equal(sql(`select pg_get_function_arguments('${signature}'::regprocedure) || '|' || pg_get_function_result('${signature}'::regprocedure)`), expected, `${signature} contract changed`);
    }
  });
  await check('current Firestore signup keys map to typed Schoolivia profile columns', async () => {
    const registerSource = readFileSync(path.resolve(root, '..', '..', 'lib', 'register_page.dart'), 'utf8');
    const mappings = [
      ['uid', 'firebase_uid', 'text'], ['name', 'full_name', 'text'], ['email', 'email', 'text'],
      ['studentId', 'student_id', 'text'], ['department', 'department', 'text'],
      ['profileCompleted', 'profile_completed', 'bool'], ['role', 'role', 'account_role'],
      ['createdAt', 'created_at', 'timestamptz'], ['updatedAt', 'updated_at', 'timestamptz'],
      ['employeeId', 'employee_id', 'text'], ['specialization', 'specialization', 'text'],
      ['status', 'teacher_status', 'teacher_status'],
    ];
    for (const [source] of mappings) assert.match(registerSource, new RegExp(`['"]${source}['"]\\s*:`), `Firestore field ${source} is absent from current registration writes`);
    const columnNames = mappings.map(([, target]) => target);
    const columnList = [...new Set(columnNames)].map(name => `'${name}'`).join(',');
    const actual = sql(`select string_agg(column_name || ':' || udt_name, ',' order by column_name) from information_schema.columns where table_schema='schoolivia' and table_name='profiles' and column_name in (${columnList})`);
    const expected = [...new Map(mappings.map(([, target, type]) => [target, `${target}:${type}`])).values()].sort().join(',');
    assert.equal(actual, expected, 'Firestore profile field target names or PostgreSQL types changed');
  });
  const studentBody = { p_first_name: 'Synthetic', p_father_name: 'Native', p_grandfather_name: 'Test', p_great_grandfather_name: 'User', p_student_id: 'NATIVE-001' };
  await check('student registration rejects each missing name component before consuming OTP proof', async () => {
    const requiredNames = ['p_first_name', 'p_father_name', 'p_grandfather_name', 'p_great_grandfather_name'];
    for (const [index, field] of requiredNames.entries()) {
      const uid = `native-empty-name-${index}`;
      const response = await http('/rpc/register_student', {
        method: 'POST',
        jwt: token(uid, 'student-native@example.invalid', { purpose: 'student.register' }),
        body: { ...studentBody, [field]: '   ' },
      });
      assert.ok(response.status >= 400, `${field} must be required; got ${response.status}`);
      assert.equal(sql(`select count(*) from schoolivia.profiles where firebase_uid='${uid}'`), '0');
      assert.equal(sql(`select count(*) from schoolivia_internal.otp_proof_uses where firebase_uid='${uid}'`), '0', 'invalid names must not consume OTP proof');
    }
  });
  await check('valid roster-bound student registration via PostgREST', async () => {
    const response = await http('/rpc/register_student', { method: 'POST', jwt: studentJwt, body: studentBody });
    assert.equal(response.status, 200, await response.text());
  });
  await check('student registration retry is idempotent', async () => {
    const first = await http('/rpc/register_student', { method: 'POST', jwt: studentJwt, body: studentBody });
    assert.equal(first.status, 200, await first.text());
  });
  await check('student academic completion accepts roster-matched gender, stage, and hall', async () => {
    const response = await http('/rpc/complete_student_registration', {
      method: 'POST', jwt: studentJwt,
      body: { p_gender: 'Female', p_stage: 'First Stage', p_hall: 'A' },
    });
    assert.equal(response.status, 204, 'void PostgREST RPC should return HTTP 204');
    assert.equal(sql("select gender || '|' || stage || '|' || hall || '|' || profile_completed::text from schoolivia.profiles where firebase_uid='native-student-uid'"), 'Female|First Stage|A|true');
  });
  await check('student academic completion rejects a stage that differs from the approved roster', async () => {
    const uid = 'native-completion-stage';
    const jwt = token(uid, 'student-completion-stage@example.invalid', { purpose: 'student.register' });
    const created = await http('/rpc/register_student', { method: 'POST', jwt, body: { ...studentBody, p_student_id: 'NATIVE-005' } });
    assert.equal(created.status, 200, await created.text());
    const response = await http('/rpc/complete_student_registration', { method: 'POST', jwt, body: { p_gender: 'Male', p_stage: 'Second Stage', p_hall: 'A' } });
    assert.ok(response.status >= 400, `roster stage mismatch must be rejected; got ${response.status}`);
    assert.equal(sql(`select profile_completed::text from schoolivia.profiles where firebase_uid='${uid}'`), 'false');
  });
  await check('student academic completion rejects a hall that differs from the approved roster', async () => {
    const uid = 'native-completion-hall';
    const jwt = token(uid, 'student-completion-hall@example.invalid', { purpose: 'student.register' });
    const created = await http('/rpc/register_student', { method: 'POST', jwt, body: { ...studentBody, p_student_id: 'NATIVE-006' } });
    assert.equal(created.status, 200, await created.text());
    const response = await http('/rpc/complete_student_registration', { method: 'POST', jwt, body: { p_gender: 'Male', p_stage: 'Second Stage', p_hall: 'A' } });
    assert.ok(response.status >= 400, `roster hall mismatch must be rejected; got ${response.status}`);
    assert.equal(sql(`select profile_completed::text from schoolivia.profiles where firebase_uid='${uid}'`), 'false');
  });
  await check('student academic completion rejects unsupported gender values', async () => {
    const uid = 'native-completion-gender';
    const jwt = token(uid, 'student-completion-gender@example.invalid', { purpose: 'student.register' });
    const created = await http('/rpc/register_student', { method: 'POST', jwt, body: { ...studentBody, p_student_id: 'NATIVE-007' } });
    assert.equal(created.status, 200, await created.text());
    const response = await http('/rpc/complete_student_registration', { method: 'POST', jwt, body: { p_gender: 'Unknown', p_stage: 'Third Stage', p_hall: 'C' } });
    assert.ok(response.status >= 400, `unsupported gender must be rejected; got ${response.status}`);
    assert.equal(sql(`select profile_completed::text from schoolivia.profiles where firebase_uid='${uid}'`), 'false');
  });
  await check('wrong email and unapproved student are rejected', async () => {
    const mismatch = await http('/rpc/register_student', { method: 'POST', jwt: token('native-mismatch','wrong-native@example.invalid',{purpose:'student.register'}), body: studentBody });
    const unapproved = await http('/rpc/register_student', { method: 'POST', jwt: token('native-unapproved','none-native@example.invalid',{purpose:'student.register'}), body: {...studentBody,p_student_id:'MISSING-001'} });
    assert.ok(mismatch.status >= 400); assert.ok(unapproved.status >= 400);
  });
  await check('expired and wrong-purpose proofs are rejected', async () => {
    const expired = await http('/rpc/register_student', { method: 'POST', jwt: token('native-expired-proof','student-native@example.invalid',{purpose:'student.register',otpExp:Math.floor(Date.now()/1000)-30}), body: studentBody });
    const wrongPurpose = await http('/rpc/register_teacher', { method: 'POST', jwt: token('native-wrong-purpose','purpose-native@example.invalid',{purpose:'student.register'}), body: { p_name:'Wrong Purpose',p_employee_id:'WP-1',p_specialization:'Linguistics' } });
    assert.ok(expired.status >= 400); assert.ok(wrongPurpose.status >= 400);
  });
  await check('proof jti is one-use across identities', async () => {
    const jti = randomBytes(20).toString('base64url');
    const first = await http('/rpc/register_student', { method: 'POST', jwt: token('native-replay-first','student-replay-one@example.invalid',{purpose:'student.register',jti}), body: {...studentBody,p_student_id:'NATIVE-003'} });
    assert.equal(first.status, 200, await first.text());
    const replay = await http('/rpc/register_student', { method: 'POST', jwt: token('native-replay-second','student-replay-two@example.invalid',{purpose:'student.register',jti}), body: {...studentBody,p_student_id:'NATIVE-004'} });
    assert.ok(replay.status >= 400);
  });
  await check('failed profile insert rolls back proof use and allows retry with the same jti', async () => {
    const jti = randomBytes(24).toString('base64url');
    const uid = 'native-fail-once-uid';
    sql(`create function public.test_native_fail_profile_insert() returns trigger language plpgsql as $$ begin if new.firebase_uid='${uid}' then raise exception 'synthetic insert failure'; end if; return new; end $$`);
    sql(`create trigger test_native_fail_profile_insert before insert on schoolivia.profiles for each row when (new.firebase_uid='${uid}') execute function public.test_native_fail_profile_insert()`);
    try {
      const jwt = token(uid, 'teacher-native@example.invalid', { purpose: 'teacher.register', jti });
      const failed = await http('/rpc/register_teacher', { method: 'POST', jwt, body: { p_name:'Synthetic Retry',p_employee_id:'NATIVE-RETRY-1',p_specialization:'Linguistics' } });
      assert.ok(failed.status >= 400, await failed.text());
      assert.equal(sql(`select count(*) from schoolivia_internal.otp_proof_uses where jti='${jti}'`), '0', 'failed profile transaction must roll back jti insert');
      sql('drop trigger test_native_fail_profile_insert on schoolivia.profiles');
      sql('drop function public.test_native_fail_profile_insert()');
      const retried = await http('/rpc/register_teacher', { method: 'POST', jwt, body: { p_name:'Synthetic Retry',p_employee_id:'NATIVE-RETRY-1',p_specialization:'Linguistics' } });
      assert.equal(retried.status, 200, await retried.text());
      assert.equal(sql(`select count(*) from schoolivia_internal.otp_proof_uses where jti='${jti}'`), '1');
    } finally {
      sql('drop trigger if exists test_native_fail_profile_insert on schoolivia.profiles');
      sql('drop function if exists public.test_native_fail_profile_insert()');
    }
  });
  await check('concurrent registrations with one jti create one profile and ledger row', async () => {
    const jti = randomBytes(24).toString('base64url');
    const candidates = [
      ['native-race-a', 'NATIVE-RACE-A'],
      ['native-race-b', 'NATIVE-RACE-B'],
    ];
    const responses = await Promise.all(candidates.map(([uid, employeeId]) => http('/rpc/register_teacher', {
      method: 'POST', jwt: token(uid, 'teacher-native@example.invalid', { purpose: 'teacher.register', jti }),
      body: { p_name:'Synthetic Race',p_employee_id:employeeId,p_specialization:'Linguistics' },
    })));
    const statuses = responses.map(response => response.status);
    assert.equal(statuses.filter(status => status === 200).length, 1, JSON.stringify(statuses));
    assert.equal(statuses.filter(status => status >= 400).length, 1, JSON.stringify(statuses));
    assert.equal(sql(`select count(*) from schoolivia_internal.otp_proof_uses where jti='${jti}'`), '1');
    assert.equal(sql("select count(*) from schoolivia.profiles where firebase_uid in ('native-race-a','native-race-b')"), '1');
  });
  await check('client verified flag without signed proof is rejected', async () => {
    const response = await http('/rpc/register_teacher', { method: 'POST', jwt: token('native-no-proof','no-proof@example.invalid'), body: { p_name:'No Proof',p_employee_id:'NP-1',p_specialization:'Linguistics',verified:true } });
    assert.ok(response.status >= 400);
  });
  await check('teacher registers pending with teacher-purpose claim', async () => {
    const response = await http('/rpc/register_teacher', { method: 'POST', jwt: teacherJwt, body: { p_name:'Synthetic Teacher',p_employee_id:'NATIVE-T-001',p_specialization:'Linguistics' } });
    assert.equal(response.status, 200, await response.text());
    assert.equal(sql("select teacher_status::text from schoolivia.profiles where firebase_uid='native-teacher-uid'"), 'pending');
  });
  await check('Arabic teacher specialization is normalized to its canonical English value', async () => {
    const uid = 'native-arabic-teacher';
    const response = await http('/rpc/register_teacher', {
      method: 'POST',
      jwt: token(uid, 'arabic-teacher-native@example.invalid', { purpose: 'teacher.register' }),
      body: { p_name: 'Synthetic Arabic Teacher', p_employee_id: 'NATIVE-T-AR', p_specialization: 'النحو' },
    });
    assert.equal(response.status, 200, await response.text());
    assert.equal(sql(`select specialization from schoolivia.profiles where firebase_uid='${uid}'`), 'Grammar');
    assert.equal(sql(`select teacher_status::text from schoolivia.profiles where firebase_uid='${uid}'`), 'pending');
  });
  await check('unknown teacher specialization is rejected without consuming OTP proof', async () => {
    const uid = 'native-unknown-specialization';
    const jti = 'native-unknown-specialization-jti';
    const response = await http('/rpc/register_teacher', {
      method: 'POST',
      jwt: token(uid, 'unknown-specialization@example.invalid', { purpose: 'teacher.register', jti }),
      body: { p_name: 'Synthetic Unknown Teacher', p_employee_id: 'NATIVE-T-BAD', p_specialization: 'Unknown Subject' },
    });
    assert.ok(response.status >= 400, `unsupported specialization must be rejected; got ${response.status}`);
    assert.equal(sql(`select count(*) from schoolivia.profiles where firebase_uid='${uid}'`), '0');
    assert.equal(sql(`select count(*) from schoolivia_internal.otp_proof_uses where jti='${jti}'`), '0');
  });
  await check('teacher cannot self-approve through the Admin lifecycle RPC', async () => {
    const teacherId = sql("select id::text from schoolivia.profiles where firebase_uid='native-teacher-uid'");
    const response = await http('/rpc/admin_set_teacher_status', { method: 'POST', jwt: teacherJwt, body: { p_teacher: teacherId, p_status: 'approved' } });
    assert.ok(response.status >= 400);
    assert.equal(sql("select teacher_status::text from schoolivia.profiles where firebase_uid='native-teacher-uid'"), 'pending');
  });
  await check('student RLS does not expose another user profile', async () => {
    const other = await http('/rpc/register_student', { method: 'POST', jwt: token('native-student-two','student-two-native@example.invalid',{purpose:'student.register'}), body: {...studentBody,p_student_id:'NATIVE-002'} });
    assert.equal(other.status, 200, await other.text());
    const response = await http('/profiles?select=firebase_uid', { jwt: studentJwt });
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).map(row => row.firebase_uid), ['native-student-uid']);
  });
  await check('teacher RLS exposes only the teacher self profile', async () => {
    const response = await http('/profiles?select=firebase_uid', { jwt: teacherJwt });
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).map(row => row.firebase_uid), ['native-teacher-uid']);
  });
  await check('missing/expired PostgREST session is rejected', async () => {
    const expired = token('native-expired','expired-native@example.invalid',{exp:Math.floor(Date.now()/1000)-600});
    const response = await http('/profiles?select=firebase_uid', { jwt: expired });
    assert.equal(response.status, 401);
  });
  process.stdout.write(`Completed ${checks} native PostgreSQL/PostgREST checks. Pre-migration backup SHA-256: ${backupHash}\n`);
} finally {
  if (server && server.exitCode === null) { server.kill(); await Promise.race([new Promise(resolve => server.once('exit', resolve)), new Promise(resolve => setTimeout(resolve, 3000))]); }
  await rm(testMigrationDir, { recursive: true, force: true });
}
