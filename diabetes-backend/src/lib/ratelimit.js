// src/lib/ratelimit.js
import rateLimit from 'express-rate-limit';

const WINDOW_MS = Number(process.env.RATE_LIMIT_WINDOW_MS ?? 10 * 60 * 1000); // 10 min
const MAX_REQ   = Number(process.env.RATE_LIMIT_MAX ?? 30);

export const authLimiter = rateLimit({
  windowMs: WINDOW_MS,
  max: MAX_REQ,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests. Please try again later.' },
});
