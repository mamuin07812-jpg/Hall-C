import assert from 'node:assert/strict';

const safeDatabase = /^schoolivia_test_[a-z0-9_]+$/;
const loopbackHosts = new Set(['127.0.0.1', 'localhost', '::1', '[::1]']);

export function parsePgServiceTarget(contents, serviceName) {
  let section = '';
  let values = {};
  for (const rawLine of contents.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#') || line.startsWith(';')) continue;
    const sectionMatch = line.match(/^\[([^\]]+)\]$/);
    if (sectionMatch) {
      if (section === serviceName) break;
      section = sectionMatch[1];
      if (section === serviceName) values = {};
      continue;
    }
    if (section !== serviceName) continue;
    const match = line.match(/^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (match) values[match[1].toLowerCase()] = match[2].replace(/^(['"])(.*)\1$/, '$2');
  }
  assert.ok(Object.keys(values).length, 'selected PostgreSQL service section must exist');
  return values;
}

export function assertDisposableTarget({ host, port, database }) {
  assert.ok(loopbackHosts.has(String(host).toLowerCase()), 'PostgreSQL target must be loopback');
  assert.match(String(database), safeDatabase, 'database name must begin schoolivia_test_');
  const numericPort = Number(port);
  assert.ok(Number.isInteger(numericPort) && numericPort >= 18000 && numericPort <= 18999,
    'PostgreSQL target port must be in the dedicated test range 18000-18999');
  return true;
}

export function assertDisposablePostgrestUri(uri) {
  const parsed = new URL(uri);
  assertDisposableTarget({ host: parsed.hostname, port: parsed.port, database: decodeURIComponent(parsed.pathname.slice(1)) });
  assert.equal(decodeURIComponent(parsed.username), 'authenticator', 'PostgREST must connect as the test authenticator role');
  return parsed;
}

export function assertExpectedServerAddress(actual, expected) {
  if (!expected) {
    assert.ok(['127.0.0.1', '::1'].includes(actual), 'PostgreSQL server address must be loopback outside a containerized CI job');
    return true;
  }
  const actualAddress = String(actual).endsWith('/32') ? String(actual).slice(0, -3) : String(actual);
  assert.equal(actualAddress, expected, 'PostgreSQL server address must match the ephemeral CI container address');
  const octets = String(expected).split('.').map(Number);
  const privateIpv4 = octets.length === 4 && octets.every(value => Number.isInteger(value) && value >= 0 && value <= 255)
    && (octets[0] === 10 || (octets[0] === 192 && octets[1] === 168)
      || (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31));
  assert.ok(privateIpv4, 'CI container address must be RFC1918 private IPv4');
  return true;
}
