// src/modules/metrics/metrics.routes.js
import express from 'express';
import { authRequired } from '../auth/auth.middleware.js'; // ✅ ADD THIS

import {
  // create
  addWeight,
  addGlucose,
  addA1c,
  addBP,
  addLipids,
  addSteps,
  // list
  listWeight,
  listGlucose,
  // summaries
  glucoseDailySeries,
  dashboardSnapshot,
  stepsWeekly,
  weightDailySeries,
  // debug
  debugPingDb,
  // latest glucose
  getLatestGlucose,
} from './metrics.controller.js';

const router = express.Router();

// ✅ Require JWT for ALL metrics routes
router.use(authRequired);

// ---------- debug ----------
router.get('/ping', (_req, res) => res.json({ ok: true, module: 'metrics' }));
router.get('/debug/db', debugPingDb);

// ---------- create ----------
router.post('/weight', addWeight);
router.post('/glucose', addGlucose);
router.post('/hba1c', addA1c);
router.post('/bp', addBP);
router.post('/lipids', addLipids);
router.post('/steps', addSteps);

// ---------- list ----------
router.get('/weight', listWeight);
router.get('/glucose', listGlucose);

// ---------- summaries ----------
router.get('/summary/glucose-daily', glucoseDailySeries);
router.get('/summary/dashboard', dashboardSnapshot);
router.get('/summary/steps-weekly', stepsWeekly);
router.get('/summary/weight-daily', weightDailySeries);

// ---------- latest glucose ----------
router.get('/glucose/latest', getLatestGlucose);

export default router;
