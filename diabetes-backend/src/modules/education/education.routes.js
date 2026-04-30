// src/modules/education/education.routes.js
import { Router } from 'express';
import {
  getCategories,
  getContents,
  getItemById,
} from './education.controller.js';

const router = Router();

// GET /api/v1/education/categories?lang=en|bn
router.get('/categories', getCategories);

// GET /api/v1/education/contents?lang=en|bn&category=DIABETES_BASICS&q=...
router.get('/contents', getContents);

// GET /api/v1/education/contents/:id?lang=en|bn
router.get('/contents/:id', getItemById);

export default router;
