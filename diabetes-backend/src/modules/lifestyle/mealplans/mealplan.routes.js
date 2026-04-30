
import { Router } from 'express';
import * as ctrl from './mealplan.controller.js';

const router = Router();

/* -------- Specific routes FIRST -------- */
router.get('/templates', ctrl.listTemplates);

// NEW: recommendation endpoint (must be BEFORE "/:id")
router.get('/recommend', ctrl.recommend);

router.get('/:id/items', ctrl.listItems);

/* -------- Generic -------- */
router.get('/', ctrl.list);
router.get('/:id', ctrl.getOne);

/* -------- Mutations -------- */
router.post('/', ctrl.create);
router.patch('/:id', ctrl.update);
router.delete('/:id', ctrl.remove);

/* -------- Item management -------- */
router.post('/:id/items', ctrl.addItem);
router.patch('/items/:itemId', ctrl.editItem);
router.delete('/items/:itemId', ctrl.removeItem);

/* -------- Assignments -------- */
router.post('/assign', ctrl.assignToUser);
router.get('/user/:userId', ctrl.listUserPlans);
router.delete('/assign/:assignmentId', ctrl.unassign);

export default router;
