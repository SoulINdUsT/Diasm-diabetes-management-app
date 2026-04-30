// src/modules/lifestyle/foods/food.service.js
import {
  createFood,
  getFoodById,
  listFoods,
  updateFood,
  deleteFood,
  listPortions as mdlListPortions,
  createPortion as mdlCreatePortion,
  updatePortion as mdlUpdatePortion,
  deletePortion as mdlDeletePortion,
} from './food.model.js';

import { round2 } from '../lifestyle.service.js';

/* ----------------- helpers ----------------- */

function mapPortionRow(r) {
  return {
    id: r.id,
    food_id: r.food_id,
    label_en: r.label_en ?? null,
    label_bn: r.label_bn ?? null,
    label: r.label_en ?? r.label_bn ?? '', // backward compatible
    grams: r.grams ?? 0,
  };
}

function withPortionMacros(food, portion) {
  const g = portion.grams || 0;
  const factor = g / 100;

  return {
    ...portion,
    kcal: round2((food.kcal_per_100g || 0) * factor),
    carb_g: round2((food.carb_g || 0) * factor),
    protein_g: round2((food.protein_g || 0) * factor),
    fat_g: round2((food.fat_g || 0) * factor),
    fiber_g: round2((food.fiber_g || 0) * factor),
    sodium_mg: round2((food.sodium_mg || 0) * factor),
  };
}

/* ----------------- foods ----------------- */

export async function addFood(data) {
  const id = await createFood(data);
  return await getFoodById(id);
}

export async function getFood(id) {
  const food = await getFoodById(id);
  if (!food) return null;

  const portions = (await mdlListPortions(id)).map(mapPortionRow);
  food.portions = portions.map((p) => withPortionMacros(food, p));
  return food;
}

// passthrough; your model already returns { rows, total }
export async function searchFoods(query) {
  return await listFoods(query);
}

export async function editFood(id, data) {
  const changed = await updateFood(id, data);
  if (!changed) return null;
  return await getFoodById(id);
}

export async function removeFood(id) {
  const affected = await deleteFood(id);
  return affected;
}

/* ----------------- portions ----------------- */

export async function listPortions(foodId) {
  const food = await getFoodById(foodId);
  if (!food) return [];

  const rows = (await mdlListPortions(foodId)).map(mapPortionRow);
  return rows.map((p) => withPortionMacros(food, p));
}

export async function addPortion(foodId, body) {
  // accept legacy {label} or new {label_en,label_bn}
  const payload = {
    ...body,
    label_en: body.label_en ?? body.label ?? '',
  };
  const id = await mdlCreatePortion(foodId, payload);

  // return the fresh list so caller doesn’t need another round trip
  const portions = await listPortions(foodId);
  return { id, portions };
}

export async function editPortion(portionId, body) {
  // accept legacy {label}
  const payload = {
    ...body,
    ...(body.label !== undefined ? { label_en: body.label } : null),
  };
  const changed = await mdlUpdatePortion(portionId, payload);
  return { changed: !!changed };
}

export async function removePortion(portionId) {
  const removed = await mdlDeletePortion(portionId);
  return { removed: !!removed };
}
