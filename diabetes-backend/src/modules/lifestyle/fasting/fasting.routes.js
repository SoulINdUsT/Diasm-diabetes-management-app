import { Router } from 'express';
import * as ctrl from './fasting.controller.js';

const router = Router();

// session lifecycle
router.post('/start', ctrl.startSession);
router.post('/event', ctrl.addEvent);
router.post('/end', ctrl.endSession);

// read views
router.get('/active', ctrl.getActive);
router.get('/history', ctrl.getHistory);
router.get('/rollup', ctrl.getRollup);
router.get('/summary', ctrl.getSummary);

export default router;
