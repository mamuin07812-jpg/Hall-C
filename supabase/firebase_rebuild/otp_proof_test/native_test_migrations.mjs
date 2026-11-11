export function rewriteFirebaseProjectIdForNativeTest(sql, testProjectId) {
  if (!/^[a-z0-9-]{6,30}$/.test(testProjectId)) throw new Error('invalid synthetic Firebase test project ID');
  const match = /https:\/\/securetoken\.google\.com\/([a-z0-9-]{6,30})/i.exec(sql);
  if (!match) throw new Error('migration does not contain the expected Firebase issuer binding');
  const sourceProjectId = match[1];
  if (!sql.includes(`aud' = '${sourceProjectId}'`)) throw new Error('migration audience does not match its Firebase issuer');
  const rewritten = sql.replaceAll(sourceProjectId, testProjectId);
  if (rewritten.includes(sourceProjectId)) throw new Error('source Firebase project ID remains in test migration');
  return rewritten;
}
