
// src/modules/auth/auth.middleware.js
import { verifyAccessToken } from '../../lib/jwt.js';

/**
 * Middleware to ensure a valid JWT is present.
 * Expects header: Authorization: Bearer <token>
 * Attaches decoded payload to req.user
 */
export function authRequired(req, res, next) {
  try {
    const header = req.headers['authorization'];
    if (!header) {
      return res.status(401).json({ error: 'Missing Authorization header' });
    }

    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({ error: 'Invalid Authorization format' });
    }

    const decoded = verifyAccessToken(token);

    if (!decoded || !decoded.id) {
      return res.status(401).json({ error: 'Invalid token payload' });
    }

    // normalize user object
    req.user = {
      id: decoded.id,
      email: decoded.email || null,
      role: decoded.role || 'user',
      ...decoded, // keep other claims if present
    };

    return next();
  } catch (err) {
    console.error('❌ Auth error:', err.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

/**
 * Middleware factory: require a specific role
 */
export function requireRole(role) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    if (req.user.role !== role) {
      return res.status(403).json({ error: 'Forbidden: insufficient role' });
    }
    return next();
  };
}
