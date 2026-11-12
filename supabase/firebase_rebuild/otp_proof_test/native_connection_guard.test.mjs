import assert from 'node:assert/strict';
import { test } from 'node:test';
import { assertDisposablePostgrestUri, assertDisposableTarget, assertExpectedServerAddress, parsePgServiceTarget } from './native_connection_guard.mjs';

test('allows only a disposable loopback database target on the dedicated port range', () => {
  assert.equal(assertDisposableTarget({ host: '127.0.0.1', port: 18432, database: 'schoolivia_test_ci_123' }), true);
  const service = parsePgServiceTarget('[production]\nhost=db.example.com\nport=5432\ndbname=postgres\n\n[test]\nhost=127.0.0.1\nport=18432\ndbname=schoolivia_test_ci_123\n', 'test');
  assert.deepEqual(service, { host: '127.0.0.1', port: '18432', dbname: 'schoolivia_test_ci_123' });
  assert.equal(assertDisposablePostgrestUri('postgres://authenticator:test@127.0.0.1:18432/schoolivia_test_ci_123').port, '18432');
});

test('accepts only the explicitly expected private address of an ephemeral CI database container', () => {
  assert.equal(assertExpectedServerAddress('172.18.0.3', '172.18.0.3'), true);
  assert.throws(() => assertExpectedServerAddress('172.18.0.4', '172.18.0.3'));
  assert.throws(() => assertExpectedServerAddress('8.8.8.8', '8.8.8.8'));
  assert.throws(() => assertExpectedServerAddress('10.0.0.1'));
});

test('rejects protected hosts, default PostgreSQL port, and non-test database names', () => {
  for (const target of [
    { host: 'db.example.com', port: 18432, database: 'schoolivia_test_ci' },
    { host: '127.0.0.1', port: 5432, database: 'schoolivia_test_ci' },
    { host: '127.0.0.1', port: 18432, database: 'postgres' },
  ]) assert.throws(() => assertDisposableTarget(target));
  assert.throws(() => assertDisposablePostgrestUri('postgres://authenticator:test@protected.example:18432/postgres'));
});
