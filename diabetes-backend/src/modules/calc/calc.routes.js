// src/modules/calc/calc.routes.js
import { Router } from "express";
import { calcBmi, calcBmr } from "./calc.controller.js";

const router = Router();

// /api/v1/calc/bmi?kg=&cm=
router.get("/bmi", calcBmi);

// /api/v1/calc/bmr?sex=&age=&kg=&cm=&activity_level=
router.get("/bmr", calcBmr);

export default router;
