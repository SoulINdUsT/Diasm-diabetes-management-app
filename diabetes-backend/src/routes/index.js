// src/routes/index.js
import { Router } from 'express';

import authRoutes from '../modules/auth/auth.routes.js';
import { authRequired } from '../modules/auth/auth.middleware.js'

import riskRoutes from '../modules/risk/risk.routes.js';
import educationRoutes from '../modules/education/education.routes.js';
import calcRouter from './calc.routes.js';
import metricsRoutes from '../modules/metrics/metrics.routes.js';
import reminderRoutes from '../modules/reminders/reminder.routes.js';

// NEW: lifestyle aggregator (foods, mealplans…)
import lifestyleRoutes from '../modules/lifestyle/lifestyle.routes.js';

const router = Router();

// Health check
router.get('/health', (_req, res) => res.json({ ok: true }));

// Public / mixed
router.use('/auth', authRoutes);
router.use('/risk', riskRoutes);
router.use('/education', educationRoutes);
router.use('/calc', calcRouter);
router.use('/metrics', metricsRoutes);

// Lifestyle domain
router.use('/lifestyle', lifestyleRoutes);

// Protected
router.use('/reminders', authRequired, reminderRoutes);

export default router;


