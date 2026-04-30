import { Router } from 'express';
import * as ctrl from './food.controller.js';
const router=Router();

router.get('/',ctrl.list);
router.get('/:id',ctrl.getOne);
router.post('/',ctrl.create);
router.patch('/:id',ctrl.update);
router.delete('/:id',ctrl.remove);

// portions
router.get('/:id/portions',ctrl.listPortions);
router.post('/:id/portions',ctrl.addPortion);
router.patch('/:id/portions/:portionId',ctrl.editPortion);
router.delete('/:id/portions/:portionId',ctrl.removePortion);

export default router;

