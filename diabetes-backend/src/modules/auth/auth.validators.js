// src/modules/auth/auth.validators.js

// helper to send validation errors consistently
function bad(res, msg) {
  return res.status(400).json({ error: msg });
}

export function validateRegister(req, res, next) {
  const { email, password, name } = req.body || {};

  if (!email || typeof email !== 'string') {
    return bad(res, 'Email is required');
  }
  if (!password || typeof password !== 'string' || password.length < 6) {
    return bad(res, 'Password must be at least 6 characters');
  }

  req.validated = {
    email: email.trim(),
    password,
    name: (name ?? '').toString().trim() || null,
  };
  return next();
}

export function validateLogin(req, res, next) {
  const { email, password } = req.body || {};

  if (!email || typeof email !== 'string') {
    return bad(res, 'Email is required');
  }
  if (!password || typeof password !== 'string') {
    return bad(res, 'Password is required');
  }

  req.validated = {
    email: email.trim(),
    password,
  };
  return next();
}
