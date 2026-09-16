import { databaseName, deferred } from './support/runtime.js';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { once } from 'node:events';
import { after, before, beforeEach, test } from 'node:test';
import crypto from 'node:crypto';
import mysql from 'mysql2/promise';
import express from 'express';

const { pool } = await import('../src/config/db.js');
const { hashPassword, sha256 } = await import('../src/lib/crypto.js');
const { signAccessToken, signRefreshToken, verifyRefreshToken, verifyAccessToken } =
  await import('../src/lib/jwt.js');
const { loginUser, refreshTokens } = await import('../src/modules/auth/auth.service.js');
const { default: authRoutes } = await import('../src/modules/auth/auth.routes.js');

let admin;
let created = false;
let server;
let baseUrl;
let passwordHash;
const syntheticPassword = 'test-only-password';

before(async () => {
  const config = pool.pool.config.connectionConfig;
  assert.equal(config.host, '127.0.0.1', 'Integration tests require loopback MySQL');
  assert.equal(config.database, databaseName);
  assert.match(databaseName, /^diasm_auth_test_[a-f0-9]{24}$/);
  assert.ok(!config.socketPath, 'Integration tests require TCP loopback');
  admin = await mysql.createConnection({
    host: '127.0.0.1', port: 3306, user: config.user, password: config.password,
  });
  // Only this newly generated database is written or dropped. No source
  // database is selected, and no existing users/sessions are copied.
  await admin.query('CREATE DATABASE `' + databaseName + '`');
  created = true;
  const [[current]] = await pool.query('SELECT DATABASE() AS name');
  assert.equal(current.name, databaseName);
  const schema = await readFile(new URL('./fixtures/auth-schema.sql', import.meta.url), 'utf8');
  for (const statement of schema.replace(/^--.*$/gm, '').split(';').filter(part => part.trim())) {
    await pool.query(statement);
  }
  passwordHash = await hashPassword(syntheticPassword);
  const app = express();
  app.use(express.json());
  app.use('/auth', authRoutes);
  server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

beforeEach(async () => {
  await pool.query('DELETE FROM sessions');
  await pool.query('DELETE FROM users');
});

after(async () => {
  if (server) await new Promise((resolve, reject) => server.close(err => err ? reject(err) : resolve()));
  await pool.end();
  try {
    if (created) {
      assert.match(databaseName, /^diasm_auth_test_[a-f0-9]{24}$/);
      await admin.query('DROP DATABASE `' + databaseName + '`');
    }
  } finally { if (admin) await admin.end(); }
});

async function seedSession() {
  const email = `test-${crypto.randomUUID()}@example.invalid`;
  await pool.execute(
    `INSERT INTO users (email, password_hash, status, email_verified_at)
     VALUES (?, ?, 'active', NOW())`, [email, passwordHash],
  );
  return loginUser({ email, password: syntheticPassword }, { ip: '127.0.0.1' });
}

async function sessionFor(token) {
  const [[row]] = await pool.execute(
    'SELECT *, UNIX_TIMESTAMP(expires_at) AS expires_at_epoch FROM sessions WHERE refresh_token_hash = ?',
    [sha256(token)],
  );
  return row;
}

async function post(path, body, headers = {}) {
  const response = await fetch(baseUrl + path, {
    method: 'POST', headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
  const result = response.status === 204 ? null : await response.json();
  return { status: response.status, body: result };
}

test('login and successful rotation store exact JWT expiry and commit one replacement', async () => {
  const initial = await seedSession();
  const oldClaims = verifyRefreshToken(initial.refreshToken);
  assert.equal(oldClaims.exp - oldClaims.iat, 7200, 'Fixture uses a non-default two-hour TTL');
  assert.equal(Number((await sessionFor(initial.refreshToken)).expires_at_epoch), oldClaims.exp);

  const result = await post('/auth/refresh', { refreshToken: initial.refreshToken });
  assert.equal(result.status, 200);
  assert.ok(result.body.refreshToken !== initial.refreshToken, 'Rotation must issue a different refresh credential');
  assert.equal(verifyAccessToken(result.body.accessToken).id, initial.user.id);
  assert.equal(verifyRefreshToken(result.body.refreshToken).id, initial.user.id);
  assert.ok((await sessionFor(initial.refreshToken)).revoked_at);
  const replacement = await sessionFor(result.body.refreshToken);
  assert.equal(replacement.revoked_at, null);
  assert.equal(Number(replacement.expires_at_epoch), verifyRefreshToken(result.body.refreshToken).exp);
  const [[counts]] = await pool.query('SELECT COUNT(*) AS total, SUM(revoked_at IS NULL) AS active FROM sessions');
  assert.equal(counts.total, 2);
  assert.equal(Number(counts.active), 1);
});

test('rejects unknown, revoked, and database-expired sessions with stable 401 codes', async () => {
  const initial = await seedSession();
  const unknown = signRefreshToken({ id: initial.user.id, jti: crypto.randomUUID() });
  let result = await post('/auth/refresh', { refreshToken: unknown });
  assert.equal(result.status, 401);
  assert.equal(result.body.code, 'REFRESH_SESSION_INVALID');
  await pool.execute('UPDATE sessions SET expires_at = DATE_SUB(NOW(), INTERVAL 1 SECOND) WHERE user_id = ?', [initial.user.id]);
  result = await post('/auth/refresh', { refreshToken: initial.refreshToken });
  assert.equal(result.status, 401);
  assert.equal(result.body.code, 'REFRESH_SESSION_INVALID');
  await pool.execute('UPDATE sessions SET expires_at = DATE_ADD(NOW(), INTERVAL 1 HOUR), revoked_at = NOW() WHERE user_id = ?', [initial.user.id]);
  result = await post('/auth/refresh', { refreshToken: initial.refreshToken });
  assert.equal(result.status, 401);
  assert.equal(result.body.code, 'REFRESH_SESSION_INVALID');
  const [[count]] = await pool.query('SELECT COUNT(*) AS total FROM sessions');
  assert.equal(count.total, 1);
});

test('two concurrent transactions cannot rotate the same session successfully', { timeout: 10000 }, async t => {
  const initial = await seedSession();
  const getConnection = pool.getConnection.bind(pool);
  const bothSelecting = deferred();
  let selects = 0;
  t.mock.method(pool, 'getConnection', async () => {
    const conn = await getConnection();
    return {
      beginTransaction: conn.beginTransaction.bind(conn),
      commit: conn.commit.bind(conn), rollback: conn.rollback.bind(conn),
      release: conn.release.bind(conn), destroy: conn.destroy.bind(conn),
      async execute(sql, params) {
        if (sql.includes('FOR UPDATE')) {
          // Force two real transactions to reach the locking read together.
          selects++;
          if (selects === 2) bothSelecting.resolve();
          await bothSelecting.promise;
        }
        return conn.execute(sql, params);
      },
    };
  });
  const results = await Promise.allSettled([
    refreshTokens({ refreshToken: initial.refreshToken }),
    refreshTokens({ refreshToken: initial.refreshToken }),
  ]);
  assert.equal(selects, 2);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  const failure = results.find(result => result.status === 'rejected');
  assert.equal(failure.reason.code, 'REFRESH_SESSION_INVALID');
  const [[counts]] = await pool.query('SELECT COUNT(*) AS total, SUM(revoked_at IS NULL) AS active FROM sessions');
  assert.equal(counts.total, 2);
  assert.equal(Number(counts.active), 1);
});

test('replacement insert failure rolls back revocation and is a sanitized 503', async () => {
  const initial = await seedSession();
  await pool.query(`CREATE TRIGGER fail_test_replacement BEFORE INSERT ON sessions
    FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'synthetic internal insert failure'`);
  try {
    const result = await post('/auth/refresh', { refreshToken: initial.refreshToken });
    assert.equal(result.status, 503);
    assert.deepEqual(result.body, {
      code: 'AUTH_SERVICE_UNAVAILABLE',
      message: 'Authentication service is temporarily unavailable. Please try again.',
    });
    assert.equal((await sessionFor(initial.refreshToken)).revoked_at, null);
    const [[count]] = await pool.query('SELECT COUNT(*) AS total FROM sessions');
    assert.equal(count.total, 1);
  } finally { await pool.query('DROP TRIGGER fail_test_replacement'); }
  // The same credential remains usable after the failed transaction.
  assert.equal((await post('/auth/refresh', { refreshToken: initial.refreshToken })).status, 200);
});

test('refresh rejects accounts blocked since login without rotating', async () => {
  const initial = await seedSession();
  await pool.execute("UPDATE users SET status = 'blocked' WHERE id = ?", [initial.user.id]);
  const result = await post('/auth/refresh', { refreshToken: initial.refreshToken });
  assert.equal(result.status, 403);
  assert.equal(result.body.code, 'ACCOUNT_INACTIVE');
  assert.equal((await sessionFor(initial.refreshToken)).revoked_at, null);
});

test('refresh rechecks required email verification without rotating', async () => {
  const initial = await seedSession();
  await pool.execute('UPDATE users SET email_verified_at = NULL WHERE id = ?', [initial.user.id]);
  const result = await post('/auth/refresh', { refreshToken: initial.refreshToken });
  assert.equal(result.status, 403);
  assert.equal(result.body.code, 'EMAIL_VERIFICATION_REQUIRED');
  assert.equal((await sessionFor(initial.refreshToken)).revoked_at, null);
});

test('logout works with expired access, is repeatable, and cannot revoke other sessions via all', async () => {
  const initial = await seedSession();
  const other = await loginUser({ email: initial.user.email, password: syntheticPassword });
  const expiredAccess = signAccessToken({ id: initial.user.id }, -1);
  const result = await post('/auth/logout', {
    refreshToken: initial.refreshToken, all: true, userId: initial.user.id,
  }, { Authorization: `Bearer ${expiredAccess}` });
  assert.equal(result.status, 204);
  assert.ok((await sessionFor(initial.refreshToken)).revoked_at);
  assert.equal((await sessionFor(other.refreshToken)).revoked_at, null);
  assert.equal((await post('/auth/logout', { refreshToken: initial.refreshToken })).status, 204);
  const revoked = await post('/auth/refresh', { refreshToken: initial.refreshToken });
  assert.equal(revoked.status, 401);
  assert.equal(revoked.body.code, 'REFRESH_SESSION_INVALID');
  const missing = await post('/auth/logout', { all: true });
  assert.equal(missing.status, 400);
  assert.equal(missing.body.code, 'REFRESH_TOKEN_REQUIRED');
  assert.equal((await sessionFor(other.refreshToken)).revoked_at, null);
});

test('logout is harmless for a valid signed token whose session no longer exists', async () => {
  const initial = await seedSession();
  await pool.execute('DELETE FROM sessions WHERE user_id = ?', [initial.user.id]);
  assert.equal((await post('/auth/logout', { refreshToken: initial.refreshToken })).status, 204);
});

test('a committed rotation with a lost response cannot be retried using the old token', async () => {
  const initial = await seedSession();
  // Discard the committed response, as if delivery failed after commit.
  await refreshTokens({ refreshToken: initial.refreshToken });
  const retry = await post('/auth/refresh', { refreshToken: initial.refreshToken });
  assert.equal(retry.status, 401);
  assert.equal(retry.body.code, 'REFRESH_SESSION_INVALID');
  const [[counts]] = await pool.query('SELECT COUNT(*) AS total, SUM(revoked_at IS NULL) AS active FROM sessions');
  assert.equal(counts.total, 2);
  assert.equal(Number(counts.active), 1);
});
