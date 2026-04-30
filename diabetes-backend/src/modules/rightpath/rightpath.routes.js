
// src/modules/rightpath/rightpath.routes.js
import express from 'express';
import {
  getToday,
  saveToday,
  getHistory,
  getWeeklySummary,
} from './rightpath.controller.js';

import { authRequired } from '../auth/auth.middleware.js';

const router = express.Router();

// ✅ Require JWT (no user=1 shim)
router.use(authRequired);

router.get('/today', getToday);
router.post('/today', saveToday);
router.get('/history', getHistory);
router.get('/weekly-summary', getWeeklySummary);

export default router;
