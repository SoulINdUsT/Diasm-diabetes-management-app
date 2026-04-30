
// src/modules/auth/auth.service.js
import { pool } from '../../config/db.js';
import { hashPassword, verifyPassword, sha256 } from '../../lib/crypto.js';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from '../../lib/jwt.js';
import { sendMail } from '../../lib/mailer.js';
import crypto from 'crypto';

const APP_BASE_URL = process.env.APP_BASE_URL || 'http://localhost:3000';
const REQUIRE_VERIFY = String(process.env.REQUIRE_EMAIL_VERIFICATION || '')
  .toLowerCase() === 'true';

/** Create a session row with hashed refresh token */
async function createSession(conn, userId, refreshToken, userAgent, ip) {
  const tokenHash = sha256(refreshToken);
  const sql = `
    INSERT INTO sessions (user_id, refresh_token_hash, user_agent, ip, expires_at, created_at, updated_at)
    VALUES (?, ?, ?, INET6_ATON(?), DATE_ADD(NOW(), INTERVAL 30 DAY), NOW(), NOW())
  `;
  await conn.execute(sql, [userId, tokenHash, userAgent || null, ip || null]);
}

/**
 * Create + email a verification token.
 * DEV: returns the raw token so controllers can echo it when DEV_ECHO_TOKENS=1
 */
async function createAndSendEmailVerification(conn, userId, email) {
  const raw = crypto.randomBytes(32).toString('hex');
  const h = sha256(raw);

  // clean old + expired tokens
  await conn.execute(
    'DELETE FROM email_verifications WHERE user_id=? OR expires_at < NOW()',
    [userId]
  );

  await conn.execute(
    `INSERT INTO email_verifications (user_id, token_hash, expires_at, created_at)
     VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 24 HOUR), NOW())`,
    [userId, h]
  );

  const link = `${APP_BASE_URL}/api/v1/auth/verify-email?token=${raw}`;
  const html = `
    <p>Hi,</p>
    <p>Please verify your email for DIAsm:</p>
    <p><a href="${link}">Verify Email</a></p>
    <p>If you didn’t sign up, you can ignore this email.</p>
  `;
  await sendMail({
    to: email,
    subject: 'Verify your email',
    html,
    text: `Verify link: ${link}`,
  });

  // IMPORTANT: give raw back (controller decides whether to expose it)
  return raw;
}

export async function registerUser({ email, password, name }) {
  const conn = await pool.getConnection();
  try {
    const [exists] = await conn.execute(
      'SELECT id FROM users WHERE email=? LIMIT 1',
      [email]
    );
    if (exists.length) throw new Error('Email already exists');

    const password_hash = await hashPassword(password);
    const [res] = await conn.execute(
      `INSERT INTO users (email, password_hash, name, role, status, created_at, updated_at)
       VALUES (?, ?, ?, 'user', 'active', NOW(), NOW())`,
      [email, password_hash, name || null]
    );

    let dev; // optional echo payload in DEV
    if (REQUIRE_VERIFY) {
      const raw = await createAndSendEmailVerification(conn, res.insertId, email);
      if (process.env.DEV_ECHO_TOKENS === '1') dev = { verifyToken: raw };
    } else {
      // If verification not required, mark as verified immediately (optional)
      await conn.execute(
        'UPDATE users SET email_verified_at = NOW(), updated_at = NOW() WHERE id=?',
        [res.insertId]
      );
    }

    return { id: res.insertId, email, name: name || null, role: 'user', dev };
  } finally {
    conn.release();
  }
}

export async function loginUser({ email, password }, ctx = {}) {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.execute(
      'SELECT id, email, role, password_hash, email_verified_at, status, name, dob, sex, location, diabetes_type FROM users WHERE email=? LIMIT 1',
      [email]
    );
    if (!rows.length) throw new Error('Invalid credentials');

    const u = rows[0];

    if (u.status && u.status !== 'active') {
      throw new Error('Account is not active');
    }

    const ok = await verifyPassword(u.password_hash, password);
    if (!ok) throw new Error('Invalid credentials');

    if (REQUIRE_VERIFY && !u.email_verified_at) {
      throw new Error('Please verify your email before logging in');
    }

    // ✅ compute profileCompleted flag (OPTION A)
    const profileCompleted =
      !!u.name &&
      !!u.dob &&
      !!u.sex &&
      !!u.location &&
      !!u.diabetes_type &&
      u.diabetes_type !== 'unknown';

    const payload = {
      id: u.id,
      email: u.email,
      role: u.role,
      profileCompleted,
    };

    const accessToken = signAccessToken(payload);
    const refreshToken = signRefreshToken({
      id: u.id,
      jti: crypto.randomUUID(),
    });

    await createSession(conn, u.id, refreshToken, ctx.userAgent, ctx.ip);

    return { user: payload, accessToken, refreshToken };
  } finally {
    conn.release();
  }
}

export async function refreshTokens({ refreshToken }, ctx = {}) {
  if (!refreshToken) throw new Error('Missing refresh token');

  // Verify signature/exp and compute hash
  verifyRefreshToken(refreshToken); // throws if invalid/expired
  const tokenHash = sha256(refreshToken);

  const conn = await pool.getConnection();
  try {
    // Confirm server-side session exists and is active
    const [sRows] = await conn.execute(
      `SELECT s.id, u.id AS user_id, u.email, u.role
         FROM sessions s
         JOIN users u ON u.id = s.user_id
        WHERE s.refresh_token_hash = ?
          AND s.revoked_at IS NULL
          AND s.expires_at > NOW()
        LIMIT 1`,
      [tokenHash]
    );
    if (!sRows.length) throw new Error('Session not found or expired');

    const s = sRows[0];

    // Rotate: revoke old session first
    await conn.execute(
      `UPDATE sessions SET revoked_at = NOW(), updated_at = NOW() WHERE id = ?`,
      [s.id]
    );

    // Issue new tokens
    const newPayload = { id: s.user_id, email: s.email, role: s.role };
    const newAccess = signAccessToken(newPayload);
    const newRefresh = signRefreshToken({
      id: s.user_id,
      jti: crypto.randomUUID(),
    });

    // Store new session
    await createSession(conn, s.user_id, newRefresh, ctx.userAgent, ctx.ip);

    return { user: newPayload, accessToken: newAccess, refreshToken: newRefresh };
  } finally {
    conn.release();
  }
}

export async function logout({ refreshToken, all = false }, userId) {
  const conn = await pool.getConnection();
  try {
    if (all) {
      if (!userId) throw new Error('Missing user');
      await conn.execute(
        `UPDATE sessions SET revoked_at = NOW(), updated_at = NOW()
          WHERE user_id = ? AND revoked_at IS NULL`,
        [userId]
      );
      return { revoked: 'all' };
    }

    if (!refreshToken) throw new Error('Missing refresh token');
    const tokenHash = sha256(refreshToken);
    const [res] = await conn.execute(
      `UPDATE sessions SET revoked_at = NOW(), updated_at = NOW()
        WHERE refresh_token_hash = ? AND revoked_at IS NULL`,
      [tokenHash]
    );
    return { revoked: res.affectedRows || 0 };
  } finally {
    conn.release();
  }
}

/* -------------------------  Password flows  --------------------------*/

export async function changePassword(userId, oldPassword, newPassword) {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.execute(
      'SELECT id, password_hash FROM users WHERE id=? LIMIT 1',
      [userId]
    );
    if (!rows.length) throw new Error('User not found');

    const ok = await verifyPassword(rows[0].password_hash, oldPassword);
    if (!ok) throw new Error('Old password is incorrect');

    const newHash = await hashPassword(newPassword);
    await conn.execute(
      'UPDATE users SET password_hash=?, updated_at=NOW() WHERE id=?',
      [newHash, userId]
    );
    await conn.execute(
      'UPDATE sessions SET revoked_at=NOW(), updated_at=NOW() WHERE user_id=? AND revoked_at IS NULL',
      [userId]
    );
    return { changed: true };
  } finally {
    conn.release();
  }
}

export async function requestPasswordReset(email, appBaseUrl = APP_BASE_URL) {
  const conn = await pool.getConnection();
  try {
    const [u] = await conn.execute('SELECT id FROM users WHERE email=? LIMIT 1', [email]);
    if (!u.length) return { requested: true };

    const userId = u[0].id;
    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = sha256(rawToken);

    await conn.execute('DELETE FROM password_resets WHERE user_id=? OR expires_at < NOW()', [userId]);
    await conn.execute(
      `INSERT INTO password_resets (user_id, token_hash, expires_at, created_at)
       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 MINUTE), NOW())`,
      [userId, tokenHash]
    );

    const link = `${appBaseUrl}/api/v1/auth/reset-password?token=${rawToken}`;
    const html = `
      <p>We received a request to reset your password.</p>
      <p><a href="${link}">Reset Password</a></p>
      <p>If you didn’t request this, you can ignore this email.</p>
    `;
    await sendMail({ to: email, subject: 'Reset your password', html, text: `Reset link: ${link}` });

    return { requested: true };
  } finally {
    conn.release();
  }
}

export async function resetPasswordWithToken(rawToken, newPassword) {
  const conn = await pool.getConnection();
  try {
    const tokenHash = sha256(rawToken);
    const [rows] = await conn.execute(
      `SELECT pr.id, pr.user_id
         FROM password_resets pr
        WHERE pr.token_hash=? AND pr.expires_at > NOW()
        LIMIT 1`,
      [tokenHash]
    );
    if (!rows.length) throw new Error('Invalid or expired reset token');

    const { id: resetId, user_id: userId } = rows[0];
    const newHash = await hashPassword(newPassword);

    await conn.execute(
      'UPDATE users SET password_hash=?, updated_at=NOW() WHERE id=?',
      [newHash, userId]
    );
    await conn.execute('DELETE FROM password_resets WHERE id=?', [resetId]);
    await conn.execute(
      'UPDATE sessions SET revoked_at=NOW(), updated_at=NOW() WHERE user_id=? AND revoked_at IS NULL',
      [userId]
    );
    return { reset: true };
  } finally {
    conn.release();
  }
}

/* -------------------------  Email verification  --------------------------*/

export async function verifyEmailToken(rawToken) {
  const conn = await pool.getConnection();
  try {
    const h = sha256(rawToken);
    const [rows] = await conn.execute(
      `SELECT ev.id, ev.user_id
         FROM email_verifications ev
        WHERE ev.token_hash = ? AND ev.expires_at > NOW()
        LIMIT 1`,
      [h]
    );
    if (!rows.length) throw new Error('Invalid or expired verification token');

    const { id: evId, user_id: userId } = rows[0];

    await conn.execute(
      'UPDATE users SET email_verified_at = NOW(), updated_at = NOW() WHERE id=?',
      [userId]
    );
    await conn.execute('DELETE FROM email_verifications WHERE id=?', [evId]);
    await conn.execute(
      'UPDATE sessions SET revoked_at = NOW(), updated_at = NOW() WHERE user_id = ? AND revoked_at IS NULL',
      [userId]
    );

    return { verified: true };
  } finally {
    conn.release();
  }
}

export async function resendVerification(email) {
  const conn = await pool.getConnection();
  try {
    const [u] = await conn.execute(
      'SELECT id, email_verified_at FROM users WHERE email=? LIMIT 1',
      [email]
    );
    if (!u.length) return { sent: true }; // don’t leak existence
    const { id: userId, email_verified_at } = u[0];
    if (email_verified_at) return { sent: true };

    await createAndSendEmailVerification(conn, userId, email);
    return { sent: true };
  } finally {
    conn.release();
  }
}

/* -------------------------  Profile update (NEW)  --------------------------*/

export async function updateUserProfile(userId, data) {
  if (!userId) throw new Error('Missing user');

  const allowedFields = ['name', 'dob', 'sex', 'location', 'diabetes_type'];
  const sets = [];
  const params = [];

  for (const key of allowedFields) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) continue;

    const value = data[key];

    // IMPORTANT: skip undefined values completely
    if (typeof value === 'undefined') continue;

    // Optionally convert empty string to NULL
    const finalValue = value === '' ? null : value;

    sets.push(`${key} = ?`);
    params.push(finalValue);
  }

  if (!sets.length) {
    // nothing to update – just return current profile
    const [rows] = await pool.execute(
      'SELECT id, email, name, dob, sex, location, diabetes_type, role FROM users WHERE id = ? LIMIT 1',
      [userId]
    );
    return rows[0] || null;
  }

  const conn = await pool.getConnection();
  try {
    await conn.execute(
      `UPDATE users
         SET ${sets.join(', ')},
             updated_at = NOW()
       WHERE id = ?`,
      [...params, userId]
    );

    const [rows] = await conn.execute(
      'SELECT id, email, name, dob, sex, location, diabetes_type, role FROM users WHERE id = ? LIMIT 1',
      [userId]
    );
    return rows[0] || null;
  } finally {
    conn.release();
  }
}

/* -------------------------  Profile read (NEW)  --------------------------*/

export async function getUserProfile(userId) {
  if (!userId) throw new Error('Missing user');

  const [rows] = await pool.execute(
    'SELECT id, email, name, dob, sex, location, diabetes_type, role FROM users WHERE id = ? LIMIT 1',
    [userId]
  );

  return rows[0] || null;
}

/* -------------------------  DEV helper (echo token)  --------------------------*/
/**
 * Re-generate a verification token and return it (plus link) in DEV only.
 */
export async function devResendAndEcho(email) {
  if (process.env.DEV_ECHO_TOKENS !== '1') {
    throw new Error('Not allowed');
  }
  const conn = await pool.getConnection();
  try {
    const [u] = await conn.execute('SELECT id FROM users WHERE email=? LIMIT 1', [email]);
    if (!u.length) throw new Error('User not found');
    const userId = u[0].id;
    const raw = await createAndSendEmailVerification(conn, userId, email);
    return {
      email,
      token: raw,
      link: `${APP_BASE_URL}/api/v1/auth/verify-email?token=${raw}`,
    };
  } finally {
    conn.release();
  }
}
