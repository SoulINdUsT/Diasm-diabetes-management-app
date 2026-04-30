// Uses: hydration_goals, hydration_events
// Views: v_hydration_today, v_hydration_today_glance, v_hydration_daily, v_hydration_7d_rollup

import pool from '../../../config/db.js';

// ---------- goals ----------
export async function upsertGoal(user_id, daily_ml) {
  const [res] = await pool.query(
    `INSERT INTO hydration_goals (user_id, daily_ml)
     VALUES (?, ?)
     ON DUPLICATE KEY UPDATE daily_ml = VALUES(daily_ml)`,
    [user_id, daily_ml]
  );
  return res.affectedRows > 0;
}

export async function getGoal(user_id) {
  const [rows] = await pool.query(
    `SELECT user_id, daily_ml FROM hydration_goals WHERE user_id = ?`,
    [user_id]
  );
  return rows[0] || null;
}

// ---------- events ----------
export async function addEvent({ user_id, event_at, volume_ml }) {
  const [res] = await pool.query(
    `INSERT INTO hydration_events (user_id, event_at, volume_ml)
     VALUES (?, ?, ?)`,
    [user_id, event_at, volume_ml]
  );
  return res.insertId;
}

export async function deleteEvent({ id, user_id }) {
  const [res] = await pool.query(
    `DELETE FROM hydration_events WHERE id = ? AND user_id = ?`,
    [id, user_id]
  );
  return res.affectedRows;
}

export async function listEventsForDay({ user_id, day }) {
  const [rows] = await pool.query(
    `SELECT id, user_id, event_at, volume_ml
       FROM hydration_events
      WHERE user_id = ?
        AND DATE(event_at) = ?
      ORDER BY event_at DESC, id DESC`,
    [user_id, day]
  );
  return rows;
}

// ---------- views / summaries ----------
export async function getToday(user_id) {
  const [rows] = await pool.query(
    `SELECT * FROM v_hydration_today WHERE user_id = ?`,
    [user_id]
  );
  return rows[0] || null;
}

export async function getTodayGlance(user_id) {
  const [rows] = await pool.query(
    `SELECT * FROM v_hydration_today_glance WHERE user_id = ?`,
    [user_id]
  );
  return rows[0] || null;
}

export async function getDaily({ user_id, limit = 60 }) {
  const [rows] = await pool.query(
    `SELECT user_id, day, total_ml
       FROM v_hydration_daily
      WHERE user_id = ?
      ORDER BY day DESC
      LIMIT ?`,
    [user_id, Number(limit)]
  );
  return rows;
}

export async function getRollup7(user_id) {
  const [rows] = await pool.query(
    `SELECT user_id, start_day, end_day, total_ml_7d, avg_ml_per_day_7d
       FROM v_hydration_7d_rollup
      WHERE user_id = ?`,
    [user_id]
  );
  return rows[0] || null;
}
