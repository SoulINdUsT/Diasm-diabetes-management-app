// src/modules/reminders/reminder.model.js
import { pool } from '../../config/db.js';

/** Safely parse JSON columns returned by mysql2 (may be string or object). */
function parseJSON(v) {
  if (v == null) return null;
  if (typeof v === 'object') return v; // already parsed
  try { return JSON.parse(v); } catch { return null; }
}

/** Normalize a DB row into clean JS types. */
function hydrate(row) {
  if (!row) return null;
  return {
    ...row,
    times_json: parseJSON(row.times_json),
    meta_json: parseJSON(row.meta_json),
    payload_json: parseJSON(row.payload_json),
  };
}

// -------------------- REMINDERS --------------------

export async function insert(userId, b) {
  const [r] = await pool.query(
    `INSERT INTO reminders
     (user_id, type, title, message_en, message_bn, timezone,
      rrule, times_json, interval_minutes,
      start_date, end_date, active, snooze_minutes, meta_json)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
    [
      userId,
      b.type, b.title, b.message_en, b.message_bn, b.timezone,
      b.rrule ?? null,
      b.times_json ? JSON.stringify(b.times_json) : null,
      b.interval_minutes ?? null,
      b.start_date,
      b.end_date ?? null,
      b.active ?? 1,
      b.snooze_minutes ?? 0,
      b.meta_json ? JSON.stringify(b.meta_json) : null,
    ]
  );
  return r.insertId;
}

export async function update(userId, id, b) {
  const [r] = await pool.query(
    `UPDATE reminders
     SET type=?, title=?, message_en=?, message_bn=?, timezone=?,
         rrule=?, times_json=?, interval_minutes=?,
         start_date=?, end_date=?, active=?, snooze_minutes=?, meta_json=?
     WHERE id=? AND user_id=?`,
    [
      b.type, b.title, b.message_en, b.message_bn, b.timezone,
      b.rrule ?? null,
      b.times_json ? JSON.stringify(b.times_json) : null,
      b.interval_minutes ?? null,
      b.start_date,
      b.end_date ?? null,
      b.active ?? 1,
      b.snooze_minutes ?? 0,
      b.meta_json ? JSON.stringify(b.meta_json) : null,
      id, userId,
    ]
  );
  return r.affectedRows;
}

export async function findAll(userId, q = {}) {
  const type = q.type ?? null;
  const active = typeof q.active === 'undefined' ? null : Number(q.active);
  const [rows] = await pool.query(
    `SELECT *
     FROM reminders
     WHERE user_id = ?
       AND (? IS NULL OR type = ?)
       AND (? IS NULL OR active = ?)
     ORDER BY updated_at DESC`,
    [userId, type, type, active, active]
  );
  return rows.map(hydrate);
}

export async function findOne(userId, id) {
  const [rows] = await pool.query(
    `SELECT * FROM reminders WHERE id=? AND user_id=? LIMIT 1`,
    [id, userId]
  );
  return hydrate(rows[0]);
}

export async function remove(userId, id) {
  const [r] = await pool.query(
    `DELETE FROM reminders WHERE id=? AND user_id=?`,
    [id, userId]
  );
  return r.affectedRows;
}

export async function toggle(userId, id) {
  const [r] = await pool.query(
    `UPDATE reminders
     SET active = IF(active=1,0,1)
     WHERE id=? AND user_id=?`,
    [id, userId]
  );
  return r.affectedRows;
}

export async function setSnooze(userId, id, minutes) {
  const [r] = await pool.query(
    `UPDATE reminders
     SET snooze_minutes = ?
     WHERE id=? AND user_id=?`,
    [minutes, id, userId]
  );
  return r.affectedRows;
}

/** For planner later: active + within date window. */
export async function findSchedulable(userId) {
  const [rows] = await pool.query(
    `SELECT *
     FROM reminders
     WHERE user_id=? AND active=1
       AND start_date <= CURDATE()
       AND (end_date IS NULL OR end_date >= CURDATE())`,
    [userId]
  );
  return rows.map(hydrate);
}

// -------------------- REMINDER EVENTS --------------------

export async function insertEvent(reminderId, scheduledAtUtc, payload = null) {
  const [r] = await pool.query(
    `INSERT INTO reminder_events
     (reminder_id, scheduled_at, status, attempt, payload_json)
     VALUES (?,?, 'SCHEDULED', 0, ?)`,
    [reminderId, scheduledAtUtc, payload ? JSON.stringify(payload) : null]
  );
  return r.insertId;
}

export async function listEvents(reminderId, fromDt = null, toDt = null) {
  const [rows] = await pool.query(
    `SELECT *
     FROM reminder_events
     WHERE reminder_id=?
       AND (? IS NULL OR scheduled_at >= ?)
       AND (? IS NULL OR scheduled_at <  ?)
     ORDER BY scheduled_at DESC`,
    [reminderId, fromDt, fromDt, toDt, toDt]
  );
  return rows.map(hydrate);
}

/** Idempotent transition: only update if current status equals expectedPrev. */
export async function updateEventStatus(eventId, newStatus, expectedPrev, payload = null, incAttempt = false) {
  const [r] = await pool.query(
    `UPDATE reminder_events
     SET status=?,
         attempt = IF(?, attempt+1, attempt),
         payload_json = ?
     WHERE id=? AND status=?`,
    [newStatus, incAttempt ? 1 : 0, payload ? JSON.stringify(payload) : null, eventId, expectedPrev]
  );
  return r.affectedRows;
}
