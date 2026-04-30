import jwt from 'jsonwebtoken';

// Read secrets + TTLs from env, with safe defaults
const ACCESS_SECRET  = process.env.JWT_ACCESS_SECRET  || 'devsecret123!';
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'dev_refresh_secret';
const ACCESS_TTL     = process.env.JWT_ACCESS_TTL     || '1h';
const REFRESH_TTL    = process.env.JWT_REFRESH_TTL    || '30d';

/**
 * Generate an access token
 */
export function signAccessToken(payload, expiresIn = ACCESS_TTL) {
  return jwt.sign(payload, ACCESS_SECRET, { expiresIn });
}

/**
 * Generate a refresh token
 */
export function signRefreshToken(payload, expiresIn = REFRESH_TTL) {
  // payload should contain { id, jti } ideally
  return jwt.sign(payload, REFRESH_SECRET, { expiresIn });
}

/**
 * Verify access token
 */
export function verifyAccessToken(token) {
  return jwt.verify(token, ACCESS_SECRET);
}

/**
 * Verify refresh token
 */
export function verifyRefreshToken(token) {
  return jwt.verify(token, REFRESH_SECRET);
}
