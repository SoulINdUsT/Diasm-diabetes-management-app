// src/modules/lifestyle/activity/activity.controller.js
import * as svc from './activity.service.js';

function ok(res, data) { res.json({ ok: true, data }); }
function bad(res, err) { res.status(400).json({ ok: false, error: err.message || String(err) }); }

// ───────── Goals ─────────
export async function putGoal(req, res) {
  try { ok(res, await svc.setGoal(req.body)); }
  catch (e) { bad(res, e); }
}
export async function getGoal(req, res) {
  try { ok(res, await svc.getGoal(req.query.user_id)); }
  catch (e) { bad(res, e); }
}

// ───────── Steps (uses bucket_start; accepts event_at alias) ─────────
export async function addSteps(req, res) {
  try {
    const {
      user_id,
      steps,
      source,
      bucket_start,     // preferred
      event_at,         // alias (will be mapped in service/model)
      bucket_minutes,   // optional
    } = req.body;

    const payload = { user_id, steps, source, bucket_start, event_at, bucket_minutes };
    ok(res, await svc.logSteps(payload));
  } catch (e) {
    bad(res, e);
  }
}
export async function deleteSteps(req, res) {
  try { ok(res, await svc.deleteSteps(req.params.id, req.query.user_id)); }
  catch (e) { bad(res, e); }
}

// ───────── Events (workouts etc.) ─────────
export async function addEvent(req, res) {
  try { ok(res, await svc.logEvent(req.body)); }
  catch (e) { bad(res, e); }
}
export async function deleteEvent(req, res) {
  try { ok(res, await svc.deleteEvent(req.params.id, req.query.user_id)); }
  catch (e) { bad(res, e); }
}

// ───────── Reads ─────────
export async function today(req, res) {
  try { ok(res, await svc.getToday(req.query.user_id)); }
  catch (e) { bad(res, e); }
}
export async function todayGlance(req, res) {
  try { ok(res, await svc.getTodayGlance(req.query.user_id)); }
  catch (e) { bad(res, e); }
}
export async function daily(req, res) {
  try { ok(res, await svc.getDaily(req.query.user_id, req.query.limit)); }
  catch (e) { bad(res, e); }
}
export async function rollup7(req, res) {
  try { ok(res, await svc.getRollup7(req.query.user_id)); }
  catch (e) { bad(res, e); }
}
export async function eventsForDay(req, res) {
  try { ok(res, await svc.getEventsForDay(req.query.user_id, req.query.day)); }
  catch (e) { bad(res, e); }
}
