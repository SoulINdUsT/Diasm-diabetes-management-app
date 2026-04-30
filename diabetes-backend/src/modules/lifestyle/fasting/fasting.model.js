import pool from '../../../config/db.js';

/* utils */
function toDateOrNow(v) {
  if (!v) return new Date();
  if (typeof v === 'string' && v.trim().toUpperCase() === 'NOW()') return new Date();
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? new Date() : d;
}

/* ---------------- SESSIONS ---------------- */

export async function startSession({ user_id, start_at, fast_kind, protocol, target_hours, notes }) {
  // NOTE: no status column in schema; "active" is end_at IS NULL
  const [res] = await pool.query(
    `INSERT INTO fasting_sessions
       (user_id, start_at, fast_kind, protocol, target_hours, notes)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [user_id, toDateOrNow(start_at), fast_kind ?? null, protocol ?? null, target_hours ?? null, notes ?? null]
  );
  return res.insertId;
}

export async function endSession({ user_id, end_at, reason }) {
  // find the latest open session for this user
  const [open] = await pool.query(
    `SELECT id, start_at FROM fasting_sessions
     WHERE user_id = ? AND end_at IS NULL
     ORDER BY id DESC LIMIT 1`,
    [user_id]
  );
  if (!open.length) return 0;

  const end = toDateOrNow(end_at);
  const id = open[0].id;

  // close the session; compute duration_min server-side
  const [res] = await pool.query(
    `UPDATE fasting_sessions
       SET end_at = ?,
           duration_min = TIMESTAMPDIFF(MINUTE, start_at, ?),
           broke_reason = COALESCE(?, broke_reason),
           updated_at = NOW()
     WHERE id = ?`,
    [end, end, reason ?? null, id]
  );
  return res.affectedRows;
}

/* ---------------- EVENTS ---------------- */

export async function addEvent({ user_id, event_at, event_type, value_num, value_text }) {
  // attach to the current open session if any (end_at IS NULL)
  const [open] = await pool.query(
    `SELECT id FROM fasting_sessions
     WHERE user_id = ? AND end_at IS NULL
     ORDER BY id DESC LIMIT 1`,
    [user_id]
  );
  const session_id = open[0]?.id ?? null;

  const [res] = await pool.query(
    `INSERT INTO fasting_events
       (session_id, user_id, event_at, event_type, value_num, value_text)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [session_id, user_id, toDateOrNow(event_at), event_type ?? null, value_num ?? null, value_text ?? null]
  );
  return res.insertId;
}

/* ---------------- READ (views) ---------------- */

export async function getActive(user_id) {
  // or build directly from sessions where end_at IS NULL — but you said the views exist
  const [rows] = await pool.query(`SELECT * FROM v_fasting_active WHERE user_id = ?`, [user_id]);
  return rows;
}

// AFTER (safe)
export async function getHistory(user_id) {
  const [rows] = await pool.query(
    `SELECT *
       FROM v_fasting_history
      WHERE user_id = ?
      ORDER BY start_at DESC, id DESC`,
    [user_id]
  );
  return rows;
}


export async function getRollup(user_id) {
  const [rows] = await pool.query(
    `SELECT * FROM v_fasting_daily_rollup WHERE user_id = ? ORDER BY day DESC`,
    [user_id]
  );
  return rows;
}

export async function getSummary(user_id) {
  const [rows] = await pool.query(
    `SELECT * FROM v_fasting_daily_summary WHERE user_id = ? ORDER BY day DESC`,
    [user_id]
  );
  return rows;
}
