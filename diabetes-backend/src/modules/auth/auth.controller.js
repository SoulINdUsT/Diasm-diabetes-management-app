// src/modules/auth/auth.controller.js
import {
  registerUser,
  loginUser,
  verifyEmailToken,
  refreshTokens as refreshTokensSvc,
  updateUserProfile,
  getUserProfile,        // 👈 NEW
} from './auth.service.js';

const REQUIRE_VERIFY =
  String(process.env.REQUIRE_EMAIL_VERIFICATION || '').toLowerCase() === 'true';

export async function register(req, res) {
  try {
    const src = req.validated || req.body || {};
    const { email, password, name } = src;

    const user = await registerUser({ email, password, name });

    return res.status(201).json({
      message: REQUIRE_VERIFY
        ? 'Registered successfully. Please verify your email.'
        : 'Registered successfully. You can log in now.',
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
      token: null,
    });
  } catch (err) {
    return res.status(400).json({ error: err.message || 'Registration failed' });
  }
}

export async function login(req, res) {
  try {
    const src = req.validated || req.body || {};
    const { email, password } = src;

    const ctx = { userAgent: req.headers['user-agent'], ip: req.ip };
    const result = await loginUser({ email, password }, ctx);

    return res.json({
      message: 'Login successful',
      user: result.user,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      profileCompleted: result.profileCompleted,   // 👈 new field
    });
  } catch (err) {
    return res.status(401).json({
      message: err.message || 'Invalid credentials',
    });
  }
}

export async function verifyEmail(req, res) {
  try {
    const token = (req.query.token || '').toString();
    const ok = await verifyEmailToken(token);
    return res.json({ verified: !!ok });
  } catch (err) {
    return res.status(400).json({ error: err.message || 'Invalid token' });
  }
}

export async function refresh(req, res) {
  try {
    const { refreshToken } = req.body || {};
    const ctx = { userAgent: req.headers['user-agent'], ip: req.ip };
    const t = await refreshTokensSvc({ refreshToken }, ctx);
    return res.json(t);
  } catch (err) {
    return res.status(401).json({ message: err.message || 'Invalid refresh token' });
  }
}

export async function updateProfile(req, res) {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const src = req.body || {};

    const profile = await updateUserProfile(userId, {
      name: src.name,
      dob: src.dob,
      sex: src.sex,
      location: src.location,
      diabetes_type: src.diabetes_type,
    });

    return res.json({
      message: 'Profile updated successfully',
      profile,
    });
  } catch (err) {
    console.error('updateProfile error:', err);
    return res.status(400).json({
      error: err.message || 'Failed to update profile',
    });
  }
}

/* -------------------------  Profile read (NEW)  --------------------------*/

export async function getProfile(req, res) {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const profile = await getUserProfile(userId);

    if (!profile) {
      return res.status(404).json({ ok: false, message: 'User not found' });
    }

    return res.json({
      ok: true,
      user: profile,
    });
  } catch (err) {
    console.error('getProfile error:', err);
    return res.status(400).json({
      error: err.message || 'Failed to load profile',
    });
  }
}
