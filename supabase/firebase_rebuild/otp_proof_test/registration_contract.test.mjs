import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../../..');
const read = (relative) => readFileSync(path.join(repo, relative), 'utf8');
const register = read('lib/register_page.dart');
const gate = read('lib/account_gate.dart');
const admin = read('lib/admin_page.dart');
const sql001 = read('supabase/firebase_rebuild/001_schoolivia.sql');
const sql003 = read('supabase/firebase_rebuild/003_app_integration_idempotent_roster.sql');
const sql004 = read('supabase/firebase_rebuild/004_verified_roster_email_binding.sql');
const sql005 = read('supabase/firebase_rebuild/005_otp_proof_registration.sql');

function functionDefinition(sql, name) {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const declaration = new RegExp(`function\\s+schoolivia\\.${escaped}\\s*\\(`, 'i');
  const match = declaration.exec(sql);
  assert.ok(match, `schoolivia.${name} definition exists`);
  const open = sql.indexOf('(', match.index);
  const close = sql.indexOf(')', open + 1);
  const returnType = sql.slice(close + 1).match(/^\s*returns\s+([\w\[\]]+)/i);
  assert.ok(returnType, `schoolivia.${name} return type exists`);
  const bodyEnd = sql.indexOf('$$;', close);
  assert.ok(bodyEnd >= 0, `schoolivia.${name} body terminator exists`);
  return { args: sql.slice(open + 1, close), result: returnType[1].toLowerCase(), sql: sql.slice(match.index, bodyEnd + 3) };
}
function argumentsOf(definition) {
  return definition.args.split(',').map((item) => item.trim().replace(/\s+/g, ' '));
}

function firestoreMap(collection) {
  const escaped = collection.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = register.match(new RegExp(`\\.collection\\(['"]${escaped}['"]\\)\\s*\\.doc\\(user\\.uid\\)\\s*\\.set\\(\\s*\\{([\\s\\S]*?)\\}\\s*\\);`));
  assert.ok(match, `Firestore ${collection} signup write exists`);
  return [...match[1].matchAll(/['"]([^'"]+)['"]\s*:/g)].map((entry) => entry[1]);
}

test('student and teacher RPC argument names, order, types, and return types stay explicit', () => {
  assert.deepEqual(argumentsOf(functionDefinition(sql005, 'register_student')), [
    'p_first_name text', 'p_father_name text', 'p_grandfather_name text',
    'p_great_grandfather_name text', 'p_student_id text',
  ]);
  assert.equal(functionDefinition(sql005, 'register_student').result, 'uuid');
  assert.deepEqual(argumentsOf(functionDefinition(sql005, 'register_teacher')), [
    'p_name text', 'p_employee_id text', 'p_specialization text',
  ]);
  assert.equal(functionDefinition(sql005, 'register_teacher').result, 'uuid');
  assert.deepEqual(argumentsOf(functionDefinition(sql005, 'complete_student_registration')), [
    'p_gender text', 'p_stage text', 'p_hall text',
  ]);
  assert.equal(functionDefinition(sql005, 'complete_student_registration').result, 'void');
});

test('student registration requires every one of the four name components on the server', () => {
  const registration = functionDefinition(sql005, 'register_student').sql;
  for (const parameter of ['p_first_name', 'p_father_name', 'p_grandfather_name', 'p_great_grandfather_name']) {
    assert.match(registration, new RegExp(`nullif\\(trim\\(${parameter}\\), ''\\) is null`), `${parameter} must be required by the database`);
  }
  assert.match(registration, /all four student name components are required/);
});

test('final approved roster importer requires the seven typed fields and admin authority', () => {
  const finalImporter = functionDefinition(sql004, 'import_approved_students');
  assert.deepEqual(argumentsOf(finalImporter), ['p_rows jsonb']);
  assert.equal(finalImporter.result, 'jsonb');
  const recordFields = [...finalImporter.sql.matchAll(/jsonb_to_recordset\(p_rows\)\s+as\s+x\s*\(([^)]*)\)/gi)];
  assert.ok(recordFields.length >= 1, 'importer parses typed row objects');
  const expected = 'university_id text, email text, full_name text, department text, stage text, hall text, enabled boolean';
  for (const [, fields] of recordFields) assert.equal(fields.replace(/\s+/g, ' ').trim(), expected);
  assert.match(finalImporter.sql, /if\s+not\s+schoolivia\.is_admin\(\)\s+then\s+raise\s+exception\s+'admin required'/i);
  assert.match(finalImporter.sql, /jsonb_typeof\(p_rows\)\s*<>\s*'array'/i);
  assert.match(finalImporter.sql, /v_input_count\s*<\s*1\s+or\s+v_input_count\s*>\s*5000/i);
  assert.match(finalImporter.sql, /duplicate student IDs/i);
  assert.match(finalImporter.sql, /duplicate emails/i);
  assert.match(finalImporter.sql, /on conflict\s*\(university_id\)\s*do update/i);

  const obsolete003 = functionDefinition(sql003, 'import_approved_students');
  assert.match(obsolete003.sql, /verified roster email binding migration 004 is required/);
  assert.doesNotMatch(obsolete003.sql, /university_id text, email text/);
  assert.doesNotMatch(sql005, /create\s+(?:or\s+replace\s+)?function\s+schoolivia\.import_approved_students/i);
});

test('current Firestore registration writes keep their actual student and teacher fields', () => {
  assert.deepEqual(firestoreMap('students'), [
    'uid', 'name', 'email', 'studentId', 'department', 'profileCompleted', 'role', 'createdAt', 'updatedAt',
  ]);
  assert.deepEqual(firestoreMap('teachers'), [
    'uid', 'name', 'email', 'employeeId', 'specialization', 'department', 'role', 'status', 'createdAt', 'updatedAt',
  ]);
  assert.doesNotMatch(register, /\.rpc\s*\(/i);
  assert.match(register, /createUserWithEmailAndPassword/);
  assert.match(register, /await user\.sendEmailVerification\(\)/);
  assert.ok(register.indexOf(".collection('students')") < register.indexOf('await user.sendEmailVerification()'));
  assert.doesNotMatch(register, /['"]emailVerified['"]\s*:/);
  assert.match(gate, /if\s*\(!user\.emailVerified\)/);
  assert.match(gate, /await user\.reload\(\)/);
  assert.match(gate, /refreshedUser\.emailVerified/);
});

test('student academic completion captures stage and group in Firestore, but not gender or Supabase RPC', () => {
  const setupStart = gate.indexOf('class _StudentSetupPageState');
  const setupEnd = gate.indexOf(String.fromCharCode(10) + 'class ', setupStart + 1);
  const setup = gate.slice(setupStart, setupEnd < 0 ? undefined : setupEnd);
  assert.match(setup, /'stage':\s*_selectedStage/);
  assert.match(setup, /'group':\s*_selectedGroup/);
  assert.match(setup, /'profileCompleted':\s*true/);
  assert.doesNotMatch(setup, /['"]gender['"]\s*:/);
  assert.doesNotMatch(setup, /\.rpc\s*\(/i);

  const completion = functionDefinition(sql005, 'complete_student_registration').sql;
  assert.match(completion, /p_gender\s+not\s+in\s*\('Male',\s*'Female',\s*'male',\s*'female'/i);
  assert.match(completion, /(?:schoolivia\.)?normalize_stage\(p_stage\)\s*<>\s*(?:schoolivia\.)?normalize_stage\(r\.stage\)/i);
  assert.match(completion, /upper\(trim\(p_hall\)\)\s*<>\s*upper\(trim\(r\.hall\)\)/i);
  assert.match(completion, /set\s+gender\s*=\s*p_gender,\s*department\s*=\s*r\.department,\s*stage\s*=\s*r\.stage,\s*hall\s*=\s*r\.hall/i);
});

test('Admin has individual Firestore student management, but no approved-roster import path', () => {
  assert.match(admin, /collection\('students'\)/);
  assert.match(admin, /profileCompleted/);
  assert.doesNotMatch(admin, /approved_students|import_approved_students|schoolivia\s*\.\s*rpc/i);
});

test('student great-grandfather name is stored separately from family name', () => {
  const migrations = [
    ['001', sql001],
    ['003', sql003],
    ['004', sql004],
    ['005', sql005],
  ];
  for (const [name, sql] of migrations) {
    const registration = functionDefinition(sql, 'register_student').sql;
    assert.match(registration, /great_grandfather_name/i, `${name} keeps the great-grandfather field`);
    assert.doesNotMatch(registration, /great_grandfather_name\s*,\s*family_name/i, `${name} must not map great-grandfather into family_name`);
    assert.doesNotMatch(registration, /nullif\(trim\(p_great_grandfather_name\),\s*''\),\s*nullif\(trim\(p_great_grandfather_name\),\s*''\)/i, `${name} must not duplicate the input value`);
  }
  assert.match(sql001, /family_name text/);
  assert.match(sql001, /p_family_name text default null/);
});