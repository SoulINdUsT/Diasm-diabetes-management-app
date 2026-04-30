
// src/modules/lifestyle/mealplans/mealplan.model.js
import pool from '../../../config/db.js';

// -------------------- PLANS --------------------

export async function createMealPlan(data) {
  const sql = `
    INSERT INTO meal_plans
      (title, calories, is_template, for_diabetes_type, source_ref, created_by)
    VALUES (?, ?, ?, ?, ?, ?)
  `;
  const params = [
    data.title,
    data.calories ?? null,
    data.is_template ?? 1,
    data.for_diabetes_type ?? 'T2D',
    data.source_ref ?? null,
    data.created_by ?? null,
  ];
  const [res] = await pool.query(sql, params);
  return res.insertId;
}

export async function getMealPlanById(id) {
  const [rows] = await pool.query(
    `SELECT id, title, calories, is_template, for_diabetes_type,
            source_ref, created_by, created_at, updated_at
     FROM meal_plans
     WHERE id = ?`,
    [id]
  );
  return rows[0] || null;
}

export async function listMealPlans({
  q,
  limit = 20,
  offset = 0,
  is_template,
  type,
}) {
  const where = [];
  const params = [];

  if (q) {
    where.push('title LIKE ?');
    params.push(`%${q}%`);
  }
  if (is_template != null) {
    where.push('is_template = ?');
    params.push(is_template);
  }
  if (type) {
    where.push('for_diabetes_type = ?');
    params.push(type);
  }

  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

  const [rows] = await pool.query(
    `SELECT id, title, calories, is_template, for_diabetes_type, source_ref, created_at
     FROM meal_plans
     ${whereSql}
     ORDER BY created_at DESC
     LIMIT ? OFFSET ?`,
    [...params, Number(limit), Number(offset)]
  );

  const [[{ total } = { total: 0 }]] = await pool.query(
    `SELECT COUNT(*) AS total FROM meal_plans ${whereSql}`,
    params
  );

  return { rows, total };
}

export async function updateMealPlan(id, data) {
  const sets = [],
    params = [];
  for (const [k, v] of Object.entries(data)) {
    if (v !== undefined) {
      sets.push(`${k} = ?`);
      params.push(v);
    }
  }
  if (!sets.length) return 0;

  const [res] = await pool.query(
    `UPDATE meal_plans SET ${sets.join(', ')}, updated_at = NOW() WHERE id = ?`,
    [...params, id]
  );
  return res.affectedRows;
}

export async function deleteMealPlan(id) {
  const [res] = await pool.query(`DELETE FROM meal_plans WHERE id = ?`, [id]);
  return res.affectedRows;
}

// ---------- NEW: closest template(s) by calories ----------

export async function recommendTemplatePlans(targetCalories, limit = 3) {
  const [rows] = await pool.query(
    `SELECT id, title, calories, is_template, for_diabetes_type, source_ref, created_at
     FROM meal_plans
     WHERE is_template = 1
     ORDER BY ABS(calories - ?) ASC
     LIMIT ?`,
    [targetCalories, Number(limit)]
  );
  return rows;
}

// -------------------- ITEMS --------------------

// Return items + food nutrition + (optional) portion labels/grams
export async function listPlanItems(planId) {
  const [rows] = await pool.query(
    `
    SELECT 
      i.id,
      i.meal_time,
      i.meal_plan_id,
      i.food_id,
      i.portion_id,
      i.custom_label,
      i.grams,
      i.notes,

      -- food
      f.name_en  AS food_name_en,
      f.name_bn  AS food_name_bn,
      f.kcal_per_100g,
      f.carb_g,
      f.protein_g,
      f.fat_g,
      f.fiber_g,
      f.sodium_mg,

      -- portion (optional)
      p.label_en AS portion_label_en,
      p.label_bn AS portion_label_bn,
      p.grams    AS portion_grams
    FROM meal_plan_items i
    JOIN foods f       ON f.id = i.food_id
    LEFT JOIN food_portions p ON p.id = i.portion_id
    WHERE i.meal_plan_id = ?
    ORDER BY 
      FIELD(i.meal_time,'breakfast','mid_morning','lunch','evening','dinner','snack'),
      i.id
    `,
    [planId]
  );
  return rows;
}

export async function addPlanItem(planId, data) {
  const [res] = await pool.query(
    `INSERT INTO meal_plan_items
      (meal_plan_id, meal_time, food_id, portion_id, custom_label, grams, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      planId,
      data.meal_time,
      data.food_id ?? null,
      data.portion_id ?? null,
      data.custom_label ?? null,
      data.grams ?? null,
      data.notes ?? null,
    ]
  );
  return res.insertId;
}

export async function updatePlanItem(itemId, data) {
  const sets = [],
    params = [];
  for (const [k, v] of Object.entries(data)) {
    if (v !== undefined) {
      sets.push(`${k} = ?`);
      params.push(v);
    }
  }
  if (!sets.length) return 0;

  const [res] = await pool.query(
    `UPDATE meal_plan_items SET ${sets.join(', ')} WHERE id = ?`,
    [...params, itemId]
  );
  return res.affectedRows;
}

export async function deletePlanItem(itemId) {
  const [res] = await pool.query(`DELETE FROM meal_plan_items WHERE id = ?`, [
    itemId,
  ]);
  return res.affectedRows;
}

// -------------------- USER ↔ PLAN --------------------
// Option B: Allow unlimited changes per day.
// Behavior:
// 1) Deactivate previous active rows for this user
// 2) Insert today's plan; if duplicate key (same user+plan+date), reactivate instead of error
// 3) Return the assignment row id deterministically

export async function assignUserPlan({
  user_id,
  meal_plan_id,
  start_date,
  active = 1,
}) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // Always deactivate current active plan(s) for the user
    await conn.query(
      `UPDATE user_meal_plans
       SET active = 0
       WHERE user_id = ? AND active = 1`,
      [user_id]
    );

    // Upsert: if same (user_id, meal_plan_id, start_date) exists, reactivate it
    await conn.query(
      `
      INSERT INTO user_meal_plans (user_id, meal_plan_id, start_date, active)
      VALUES (?, ?, COALESCE(?, CURDATE()), ?)
      ON DUPLICATE KEY UPDATE
        active = VALUES(active)
      `,
      [user_id, meal_plan_id, start_date ?? null, active]
    );

    // Fetch the row id (works for both insert and duplicate update)
    const [rows] = await conn.query(
      `
      SELECT id
      FROM user_meal_plans
      WHERE user_id = ?
        AND meal_plan_id = ?
        AND start_date = COALESCE(?, CURDATE())
      ORDER BY id DESC
      LIMIT 1
      `,
      [user_id, meal_plan_id, start_date ?? null]
    );

    await conn.commit();
    return rows?.[0]?.id ?? null;
  } catch (e) {
    await conn.rollback();
    throw e;
  } finally {
    conn.release();
  }
}

export async function listUserPlans(user_id) {
  const [rows] = await pool.query(
    `SELECT ump.id, ump.start_date, ump.active,
            mp.id AS meal_plan_id, mp.title, mp.calories, mp.for_diabetes_type
     FROM user_meal_plans ump
     JOIN meal_plans mp ON mp.id = ump.meal_plan_id
     WHERE ump.user_id = ?
     ORDER BY ump.start_date DESC, ump.id DESC`,
    [user_id]
  );
  return rows;
}

export async function unassignUserPlan(assignmentId) {
  const [res] = await pool.query(
    `DELETE FROM user_meal_plans WHERE id = ?`,
    [assignmentId]
  );
  return res.affectedRows;
}
