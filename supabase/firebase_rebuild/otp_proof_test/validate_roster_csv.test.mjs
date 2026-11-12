import assert from 'node:assert/strict';
import test from 'node:test';
import { validateRosterCsv } from './validate_roster_csv.mjs';

const header = 'university_id,email,full_name,department,stage,hall,enabled';
const valid = (id = 'STU-001', email = 'one@example.edu', name = 'Student One') =>
  `${id},${email},${name},English Language,First Stage,A,true`;

test('accepts the exact seven-column roster contract and quoted commas', () => {
  const result = validateRosterCsv(`${header}\n${valid('STU-001', 'one@example.edu', '"Student, One"')}\n`);
  assert.equal(result.valid, true);
  assert.equal(result.rowCount, 1);
  assert.deepEqual(result.errors, []);
});

test('rejects header drift and empty roster data', () => {
  assert.equal(validateRosterCsv('id,email,name\n' + valid()).errors[0].code, 'header_mismatch');
  assert.equal(validateRosterCsv(header + '\n').errors[0].code, 'no_student_rows');
});

test('rejects duplicate IDs and emails case-insensitively', () => {
  const result = validateRosterCsv(`${header}\n${valid('STU-001', 'one@example.edu')}\n${valid('stu-001', 'ONE@example.edu', 'Student Two')}\n`);
  assert.equal(result.valid, false);
  assert.equal(result.errors.filter(error => error.code === 'duplicate').length, 2);
});

test('rejects invalid email, stage, hall, and enabled value', () => {
  const result = validateRosterCsv(`${header}\nSTU-001,not-an-email,Student,English Language,Stage 9,Z,yes\n`);
  assert.deepEqual(result.errors.map(error => error.code).sort(), ['invalid_boolean', 'invalid_email', 'invalid_hall', 'invalid_stage']);
});

test('rejects rows with missing required fields or wrong column count', () => {
  const result = validateRosterCsv(`${header}\nSTU-001,,Student,English Language,First Stage,A,true\nSTU-002,too,few\n`);
  assert.ok(result.errors.some(error => error.code === 'required' && error.field === 'email'));
  assert.ok(result.errors.some(error => error.code === 'column_count'));
});

test('rejects malformed quoted CSV without echoing row data', () => {
  const result = validateRosterCsv(`${header}\nSTU-001,one@example.edu,"Unclosed,English Language,First Stage,A,true`);
  assert.equal(result.valid, false);
  assert.equal(result.errors[0].code, 'malformed_csv');
  assert.equal(JSON.stringify(result).includes('one@example.edu'), false);
});

test('enforces the database maximum batch size of 5000', () => {
  const rows = Array.from({ length: 5001 }, (_, i) => valid(`STU-${i}`, `student${i}@example.edu`));
  const result = validateRosterCsv(`${header}\n${rows.join('\n')}\n`);
  assert.ok(result.errors.some(error => error.code === 'batch_over_5000'));
});
