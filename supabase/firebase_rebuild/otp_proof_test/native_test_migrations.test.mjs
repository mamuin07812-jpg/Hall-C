import assert from 'node:assert/strict';
import { test } from 'node:test';
import { rewriteFirebaseProjectIdForNativeTest } from './native_test_migrations.mjs';

test('native test migration rewrite uses only a synthetic Firebase project identifier', () => {
  const source = "iss = 'https://securetoken.google.com/source-firebase-project-123' and aud' = 'source-firebase-project-123'";
  const output = rewriteFirebaseProjectIdForNativeTest(source, 'schoolivia-native-test');
  assert.equal(output, "iss = 'https://securetoken.google.com/schoolivia-native-test' and aud' = 'schoolivia-native-test'");
  assert.ok(!output.includes('source-firebase-project-123'));
});

test('rewrite fails closed when migration issuer and audience are inconsistent', () => {
  assert.throws(() => rewriteFirebaseProjectIdForNativeTest("iss = 'https://securetoken.google.com/source-test-project' and aud' = 'other-test-project'", 'schoolivia-native-test'));
});
