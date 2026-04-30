// src/modules/lifestyle/activity/activity.model.js
import pool from '../../../config/db.js';

/**
 * Tables:
 *  - activity_goals(user_id PK, daily_steps, weekly_min?)
 *  - activity_steps(id PK AI, user_id, event_at, steps, source, created_at)
 *  - activity_events(id PK AI, user_id, event_at, event_type, minutes, distance_km, kcal, source, notes, created_at)
 *
 * Views:
 *  - v_activity_today
 *  - v_activity_today_glance
 *  - v_activity_daily
 *  - v_activity_7d_rollup
 */

// ============================================================
// ---------- GOALS ----------
// ============================================================

export async function upsertGoal({ user_id, daily_steps, weekly_min = 150 }) {
  const sql = `
    INSERT INTO activity_goals (user_id, daily_steps, weekly_min)
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE
      daily_steps = VALUES(daily_steps),
      weekly_min  = VALUES(weekly_min)
  `;
  const [res] = await pool.query(sql, [user_id, daily_steps, weekly_min]);
  return res.affectedRows;
}

export async function getGoal(user_id) {
  const [rows] = await pool.query(
    `SELECT user_id, daily_steps, weekly_min FROM activity_goals WHERE user_id = ?`,
    [user_id]
  );
  return rows[0] || null;
}

// ============================================================
// ---------- STEPS (simple counter events) ----------
// ============================================================

// src/modules/lifestyle/activity/activity.model.js
// INSERT steps – map client event time to bucket_start
export async function addSteps({
  user_id,
  steps,
  source,
  event_at,        // allow alias from client
  bucket_start,    // preferred name
  bucket_minutes,  // optional; default 15 in DB
}) {
  // If client sent "NOW()", let MySQL set NOW() server-side
  const ts = (bucket_start ?? event_at);
  const tsOrNull = ts && ts !== 'NOW()' ? ts : null;

  const minutes = Number.isFinite(Number(bucket_minutes))
    ? Number(bucket_minutes)
    : null; // COALESCE -> 15

  const sql = `
    INSERT INTO activity_steps (user_id, bucket_start, bucket_minutes, steps, source)
    VALUES (?, COALESCE(?, NOW()), COALESCE(?, 15), ?, ?)
  `;
  const [res] = await pool.query(sql, [
    user_id,
    tsOrNull,
    minutes,
    steps,
    source ?? 'manual',
  ]);
  return res.insertId;
}

export async function removeSteps(id, user_id) {
  const [res] = await pool.query(
    `DELETE FROM activity_steps WHERE id = ? AND user_id = ?`,
    [id, user_id]
  );
  return res.affectedRows;
}

// ============================================================
// ---------- WORKOUT / ACTIVITY EVENTS ----------
// ============================================================

export async function addEvent({
  user_id,
  event_type,
  minutes,
  distance_km,
  kcal,
  event_at,
  source,
  notes
}) {
  const ts = event_at && event_at !== 'NOW()' ? event_at : null;

  const sql = `
    INSERT INTO activity_events
      (user_id, event_at, event_type, minutes, distance_km, kcal, source, notes)
    VALUES (?, COALESCE(?, NOW()), ?, ?, ?, ?, ?, ?)
  `;

  const [res] = await pool.query(sql, [
    user_id,
    ts,
    event_type || 'workout',
    minutes ?? null,
    distance_km ?? null,
    kcal ?? null,
    source || 'manual',
    notes || null
  ]);

  return res.insertId;
}

export async function removeEvent(id, user_id) {
  const [res] = await pool.query(
    `DELETE FROM activity_events WHERE id = ? AND user_id = ?`,
    [id, user_id]
  );
  return res.affectedRows;
}

// ============================================================
// ---------- READS (Views) ----------
// ============================================================

export async function today(user_id) {
  const [rows] = await pool.query(
    `SELECT * FROM v_activity_today WHERE user_id = ?`,
    [user_id]
  );
  return rows;
}

export async function todayGlance(user_id) {
  const [rows] = await pool.query(
    `SELECT * FROM v_activity_today_glance WHERE user_id = ?`,
    [user_id]
  );
  return rows;
}

export async function daily(user_id, limit = 60) {
  const [rows] = await pool.query(
    `
    SELECT * FROM v_activity_daily
    WHERE user_id = ?
    ORDER BY day DESC
    LIMIT ?
    `,
    [user_id, Number(limit)]
  );
  return rows;
}

export async function rollup7(user_id) {
  const [rows] = await pool.query(
    `SELECT * FROM v_activity_7d_rollup WHERE user_id = ?`,
    [user_id]
  );
  return rows;
}

// ============================================================
// ---------- DAY DETAIL (both steps + events) ----------
// ============================================================

// ---------- Day detail (both steps + events) ----------
// src/modules/lifestyle/activity/activity.model.js

export async function eventsForDay(user_id, day /* 'YYYY-MM-DD' */) {
  const sql = `
    SELECT
      COALESCE(s.bucket_start, s.created_at) AS event_at,
      'steps' AS kind,
      s.id,
      s.steps AS amount,
      NULL AS event_type,
      NULL AS minutes,
      NULL AS distance_km,
      NULL AS kcal,
      s.source,
      NULL AS notes
    FROM activity_steps s
    WHERE s.user_id = ?
      AND DATE(COALESCE(s.bucket_start, s.created_at)) = ?

    UNION ALL

    SELECT
      COALESCE(e.event_at, e.created_at) AS event_at,
      e.event_type AS kind,
      e.id,
      NULL AS amount,
      e.event_type,
      e.minutes,
      e.distance_km,
      e.kcal,
      e.source,
      e.notes
    FROM activity_events e
    WHERE e.user_id = ?
      AND DATE(COALESCE(e.event_at, e.created_at)) = ?

    ORDER BY event_at DESC, kind DESC
  `;
  const [rows] = await pool.query(sql, [user_id, day, user_id, day]);
  return rows;
}
