import { readFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const ROSTER_HEADERS = Object.freeze([
  'university_id', 'email', 'full_name', 'department', 'stage', 'hall', 'enabled',
]);
const STAGES = new Set(['First Stage', 'Second Stage', 'Third Stage', 'Fourth Stage']);
const HALLS = new Set(['A', 'B', 'C', 'D']);

function parseCsv(source) {
  const rows = [];
  let row = [];
  let field = '';
  let quoted = false;
  const input = source.replace(/^\uFEFF/, '');
  for (let i = 0; i < input.length; i += 1) {
    const char = input[i];
    if (quoted) {
      if (char === '"' && input[i + 1] === '"') { field += '"'; i += 1; }
      else if (char === '"') quoted = false;
      else field += char;
    } else if (char === '"' && field.length === 0) quoted = true;
    else if (char === ',') { row.push(field); field = ''; }
    else if (char === '\n' || char === '\r') {
      if (char === '\r' && input[i + 1] === '\n') i += 1;
      row.push(field); field = '';
      if (row.some(value => value.length > 0)) rows.push(row);
      row = [];
    } else field += char;
  }
  if (quoted) throw new Error('CSV contains an unclosed quoted field');
  if (field.length || row.length) {
    row.push(field);
    if (row.some(value => value.length > 0)) rows.push(row);
  }
  return rows;
}

export function validateRosterCsv(source) {
  const errors = [];
  let rows;
  try { rows = parseCsv(source); }
  catch { return { valid: false, rowCount: 0, errors: [{ line: 1, field: 'CSV', code: 'malformed_csv' }] }; }
  if (rows.length === 0) return { valid: false, rowCount: 0, errors: [{ line: 1, field: 'CSV', code: 'missing_header' }] };

  const headers = rows[0].map(value => value.trim());
  if (headers.length !== ROSTER_HEADERS.length || headers.some((value, i) => value !== ROSTER_HEADERS[i])) {
    errors.push({ line: 1, field: 'header', code: 'header_mismatch' });
    return { valid: false, rowCount: 0, errors };
  }
  if (rows.length === 1) errors.push({ line: 2, field: 'row', code: 'no_student_rows' });
  if (rows.length - 1 > 5000) errors.push({ line: 1, field: 'row', code: 'batch_over_5000' });

  const ids = new Set();
  const emails = new Set();
  const dataRows = rows.slice(1);
  for (let index = 0; index < dataRows.length; index += 1) {
    const line = index + 2;
    const values = dataRows[index];
    if (values.length !== ROSTER_HEADERS.length) {
      errors.push({ line, field: 'row', code: 'column_count' });
      continue;
    }
    const record = Object.fromEntries(ROSTER_HEADERS.map((key, i) => [key, values[i].trim()]));
    for (const key of ['university_id', 'email', 'full_name', 'department', 'stage', 'hall', 'enabled']) {
      if (!record[key]) errors.push({ line, field: key, code: 'required' });
    }
    const id = record.university_id.toLowerCase();
    if (id && ids.has(id)) errors.push({ line, field: 'university_id', code: 'duplicate' });
    if (id) ids.add(id);
    const email = record.email.toLowerCase();
    if (email && (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) errors.push({ line, field: 'email', code: 'invalid_email' });
    if (email && emails.has(email)) errors.push({ line, field: 'email', code: 'duplicate' });
    if (email) emails.add(email);
    if (record.stage && !STAGES.has(record.stage)) errors.push({ line, field: 'stage', code: 'invalid_stage' });
    if (record.hall && !HALLS.has(record.hall.toUpperCase())) errors.push({ line, field: 'hall', code: 'invalid_hall' });
    if (record.enabled && !['true', 'false'].includes(record.enabled.toLowerCase())) errors.push({ line, field: 'enabled', code: 'invalid_boolean' });
  }
  return { valid: errors.length === 0, rowCount: dataRows.length, errors };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const file = process.argv[2];
  if (!file) {
    process.stderr.write('Usage: node validate_roster_csv.mjs <roster.csv>\n');
    process.exitCode = 2;
  } else {
    const result = validateRosterCsv(readFileSync(file, 'utf8'));
    if (result.valid) process.stdout.write(`PASS: ${result.rowCount} roster rows; no student data printed.\n`);
    else {
      process.stderr.write(`FAIL: ${result.errors.length} validation issue(s); ${result.rowCount} data row(s) scanned.\n`);
      for (const error of result.errors) process.stderr.write(`line ${error.line}: ${error.field} — ${error.code}\n`);
      process.exitCode = 1;
    }
  }
}
