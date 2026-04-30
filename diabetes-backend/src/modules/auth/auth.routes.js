
// src/modules/auth/auth.routes.js
import { Router } from 'express';
import {
  register,
  login,
  verifyEmail,
  refresh,
  updateProfile,
  getProfile,          // 👈 NEW
} from './auth.controller.js';

import { validateRegister, validateLogin } from './auth.validators.js';
import { authRequired } from './auth.middleware.js';  // ✅ correct place

const r = Router();

// Public routes
r.post('/register', validateRegister, register);
r.post('/login', validateLogin, login);
r.get('/verify-email', verifyEmail);

// Token refresh
r.post('/refresh', refresh);

// Protected profile read + update
r.get('/profile', authRequired, getProfile);     // 👈 NEW
r.patch('/profile', authRequired, updateProfile);

export default r;
