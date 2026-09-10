import './support/runtime.js';
import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';

const { pool } = await import('../src/config/db.js');
const { signRefreshToken } = await import('../src/lib/jwt.js');
const { refreshTokens, logout } = await import('../src/modules/auth/auth.service.js');
const controller = await import('../src/modules/auth/auth.controller.js');
after(() => pool.end());

function response() {
  return {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
    end() { return this; },
  };
}

function request(refreshToken) {
  return { body: { refreshToken }, headers: {}, ip: '127.0.0.1' };
}

test('rejects missing, malformed, expired, and incorrectly signed credentials without using DB', async t => {
  const connection = t.mock.method(pool, 'getConnection', () => {
    throw new Error('Database must not be contacted for invalid credentials');
  });
  const cases = [
    [undefined, 400, 'REFRESH_TOKEN_REQUIRED'],
    ['', 400, 'REFRESH_TOKEN_REQUIRED'],
    [{ token: 'invalid' }, 400, 'REFRESH_TOKEN_REQUIRED'],
    ['invalid', 401, 'REFRESH_TOKEN_INVALID'],
    [signRefreshToken({ id: 1, jti: 'test' }, -1), 401, 'REFRESH_TOKEN_EXPIRED'],
    [jwt.sign({ id: 1, jti: 'test' }, 'synthetic-wrong-key', { expiresIn: '1h' }), 401, 'REFRESH_TOKEN_INVALID'],
    [signRefreshToken({ id: 1 }), 401, 'REFRESH_TOKEN_INVALID'],
    [jwt.sign({ id: 1, jti: 'test' }, process.env.JWT_REFRESH_SECRET), 401, 'REFRESH_TOKEN_INVALID'],
    [jwt.sign({ id: 1, jti: 'test' }, process.env.JWT_REFRESH_SECRET, { expiresIn: '1h', notBefore: '1h' }), 401, 'REFRESH_TOKEN_INVALID'],
  ];
  for (const [token, status, code] of cases) {
    for (const handler of [controller.refresh, controller.logout]) {
      const res = response();
      await handler(request(token), res);
      assert.equal(res.statusCode, status);
      assert.equal(res.body.code, code);
    }
  }
  assert.equal(connection.mock.callCount(), 0);
});

test('connection failure is a sanitized 503 for refresh and logout', async t => {
  t.mock.method(pool, 'getConnection', async () => {
    throw Object.assign(new Error('synthetic private connection details'), { code: 'ECONNREFUSED' });
  });
  const token = signRefreshToken({ id: 1, jti: 'test' });
  for (const handler of [controller.refresh, controller.logout]) {
    const res = response();
    await handler(request(token), res);
    assert.equal(res.statusCode, 503);
    assert.deepEqual(res.body, {
      code: 'AUTH_SERVICE_UNAVAILABLE',
      message: 'Authentication service is temporarily unavailable. Please try again.',
    });
  }
});

test('query failure rolls back and releases; rollback failure destroys the connection', async t => {
  for (const rollbackFails of [false, true]) {
    const calls = [];
    const conn = {
      async beginTransaction() { calls.push('begin'); },
      async execute() { calls.push('query'); throw new Error('synthetic SQL failure'); },
      async rollback() {
        calls.push('rollback');
        if (rollbackFails) throw new Error('synthetic lost connection');
      },
      release() { calls.push('release'); },
      destroy() { calls.push('destroy'); },
    };
    const mocked = t.mock.method(pool, 'getConnection', async () => conn);
    const res = response();
    await controller.refresh(request(signRefreshToken({ id: 1, jti: 'test' })), res);
    assert.equal(res.statusCode, 503);
    assert.equal(res.body.code, 'AUTH_SERVICE_UNAVAILABLE');
    assert.deepEqual(calls, ['begin', 'query', 'rollback', rollbackFails ? 'destroy' : 'release']);
    mocked.mock.restore();
  }
});

test('begin failure releases the connection without attempting rollback', async t => {
  const calls = [];
  t.mock.method(pool, 'getConnection', async () => ({
    async beginTransaction() { throw new Error('synthetic begin failure'); },
    async rollback() { calls.push('rollback'); },
    release() { calls.push('release'); },
  }));
  await assert.rejects(refreshTokens({ refreshToken: signRefreshToken({ id: 1, jti: 'test' }) }));
  assert.deepEqual(calls, ['release']);
});

test('logout service validates credentials before acquiring a connection', async t => {
  const connection = t.mock.method(pool, 'getConnection', () => {
    throw new Error('unexpected database access');
  });
  await assert.rejects(logout({ refreshToken: 'invalid' }), { code: 'REFRESH_TOKEN_INVALID' });
  assert.equal(connection.mock.callCount(), 0);
});
