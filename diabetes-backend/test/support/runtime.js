import crypto from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// Set these BEFORE dynamically importing application modules (mailer imports
// dotenv). Never load the workspace .env or inherit deployment credentials.
process.env.DOTENV_CONFIG_PATH = join(tmpdir(), `diasm-no-env-${crypto.randomUUID()}`);
process.env.MAIL_ENABLED = 'false';
process.env.JWT_ACCESS_SECRET = crypto.randomBytes(32).toString('hex');
process.env.JWT_REFRESH_SECRET = crypto.randomBytes(32).toString('hex');
process.env.JWT_ACCESS_TTL = '1h';
process.env.JWT_REFRESH_TTL = '2h';
process.env.REQUIRE_EMAIL_VERIFICATION = 'true';
process.env.DB_HOST = '127.0.0.1';
export const databaseName = `diasm_auth_test_${crypto.randomBytes(12).toString('hex')}`;
process.env.DB_NAME = databaseName;
for (const [target, source] of [
  ['DB_USER', 'DIASM_TEST_DB_USER'],
  ['DB_PASS', 'DIASM_TEST_DB_PASSWORD'],
]) {
  if (process.env[source] !== undefined) process.env[target] = process.env[source];
  else delete process.env[target]; // Use the existing local db.js defaults.
}

export function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}
