
// src/modules/lifestyle/mealplans/mealplan.service.js
import {
  createMealPlan,
  updateMealPlan,
  deleteMealPlan,
  getMealPlanById,
  listMealPlans,
  listPlanItems,
  addPlanItem,
  updatePlanItem,
  deletePlanItem,
  assignUserPlan,
  listUserPlans,
  unassignUserPlan,
  recommendTemplatePlans, // NEW import
} from './mealplan.model.js';
import { round2 } from '../lifestyle.service.js';

// Compute per-item macros from food-per-100g and grams/portion
function computeItemMacros(row) {
  const grams = Number(row.grams ?? row.portion_grams ?? 0) || 0;
  const kcal100 = Number(row.kcal_per_100g || 0);
  const p100 = Number(row.protein_g || 0);
  const c100 = Number(row.carb_g || 0);
  const f100 = Number(row.fat_g || 0);

  return {
    grams,
    calories: round2((kcal100 * grams) / 100),
    protein_g: round2((p100 * grams) / 100),
    carbs_g: round2((c100 * grams) / 100),
    fat_g: round2((f100 * grams) / 100),
  };
}

export async function createPlan(data) {
  const id = await createMealPlan(data);
  return await getMealPlanById(id);
}

export async function editPlan(id, data) {
  const n = await updateMealPlan(id, data);
  if (!n) return null;
  return await getMealPlanById(id);
}

export async function removePlan(id) {
  return await deleteMealPlan(id);
}

export async function getPlan(id) {
  const plan = await getMealPlanById(id);
  if (!plan) return null;

  const items = await listPlanItems(id);

  const byMeal = {};
  let totals = { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 };

  for (const r of items) {
    const m = computeItemMacros(r);
    const entry = {
      id: r.id,
      meal_time: r.meal_time,
      food_id: r.food_id,
      food_name_en: r.food_name_en,
      food_name_bn: r.food_name_bn,
      portion_id: r.portion_id,
      portion_label_en: r.portion_label_en,
      portion_label_bn: r.portion_label_bn,
      grams: m.grams,
      custom_label: r.custom_label,
      notes: r.notes ?? '',
      calories: m.calories,
      protein_g: m.protein_g,
      carbs_g: m.carbs_g,
      fat_g: m.fat_g,
    };

    (byMeal[r.meal_time] ??= []).push(entry);
    totals.calories += m.calories;
    totals.protein_g += m.protein_g;
    totals.carbs_g += m.protein_g;
    totals.fat_g += m.fat_g;
  }

  totals = Object.fromEntries(
    Object.entries(totals).map(([k, v]) => [k, round2(v)])
  );

  return { ...plan, items_by_meal: byMeal, totals };
}

export async function searchPlans(q) {
  return await listMealPlans(q);
}

// ---------- NEW: recommend a template based on target calories ----------

export async function recommendTemplatePlan(targetCalories) {
  const t = Number(targetCalories);
  if (!t || Number.isNaN(t) || t <= 0) {
    throw new Error('Invalid target_calories');
  }

  const rows = await recommendTemplatePlans(t, 3); // closest 3 templates
  if (!rows.length) {
    return {
      target_calories: t,
      recommended_plan: null,
      alternatives: [],
    };
  }

  const [recommended, ...alternatives] = rows;
  return {
    target_calories: t,
    recommended_plan: recommended,
    alternatives,
  };
}

// -------------------- items --------------------

export async function addItem(planId, data) {
  const id = await addPlanItem(planId, data);
  return { id };
}
export async function editItem(itemId, data) {
  const n = await updatePlanItem(itemId, data);
  return { updated: !!n };
}
export async function removeItem(itemId) {
  const n = await deletePlanItem(itemId);
  return { removed: !!n };
}

// -------------------- user assignments --------------------

export async function assignPlanToUser(payload) {
  // IMPORTANT: model handles default date via SQL COALESCE(?, CURDATE())
  const id = await assignUserPlan(payload);
  return id;
}

export async function getUserPlans(user_id) {
  return await listUserPlans(user_id);
}
export async function unassignPlan(assignmentId) {
  const n = await unassignUserPlan(assignmentId);
  return { removed: !!n };
}
