// src/modules/lifestyle/lifestyle.routes.js
import { Router } from 'express';

// Submodules (add others as they’re built)
import foodRoutes from './foods/food.routes.js';
import mealPlanRoutes from './mealplans/mealplan.routes.js';

import fastingRoutes from './fasting/fasting.routes.js';
 import activityRoutes from './activity/activity.routes.js';
 import hydrationRoutes from './hydration/hydration.routes.js';
 import { snapshot } from './lifestyle.controller.js';



const router = Router();

router.use('/foods', foodRoutes);
router.use('/mealplans', mealPlanRoutes);
router.use('/fasting', fastingRoutes);
 router.use('/activity', activityRoutes);
 router.use('/hydration', hydrationRoutes);
 router.get('/snapshot', snapshot);



export default router;
