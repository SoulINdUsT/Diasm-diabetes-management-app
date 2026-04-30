import * as svc from './hydration.service.js';

export async function setGoal(req, res) {
  try {
    const { user_id, daily_ml } = req.body;
    const data = await svc.setGoal(Number(user_id), Number(daily_ml));
    res.json({ ok: true, data });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
}

export async function getGoal(req, res) {
  try {
    const { user_id } = req.query;
    const data = await svc.getGoal(Number(user_id));
    res.json({ ok: true, data });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
}

export async function addEvent(req, res) {
  try {
    const { user_id, event_at = 'NOW()', volume_ml } = req.body;
    // If client passes "NOW()", let MySQL evaluate it. Otherwise pass given datetime.
    const ts = String(event_at).toUpperCase() === 'NOW()' ? new Date() : new Date(event_at);
    const data = await svc.logEvent({ user_id: Number(user_id), event_at: ts, volume_ml: Number(volume_ml) });
    res.json({ ok: true, ...data });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
}

export async function deleteEvent(req, res) {
  try {
    const { id } = req.params;
    const { user_id } = req.query;
    const data = await svc.removeEvent({ id: Number(id), user_id: Number(user_id) });
    res.json({ ok: true, ...data });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
}

export async function listEventsForDay(req, res) {
  try {
    const { user_id, day } = req.query;
    const rows = await svc.eventsForDay({ user_id: Number(user_id), day });
    res.json({ ok: true, rows });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
}

export async function today(req, res) {
  try {
    const { user_id } = req.query;
    const data = await svc.today(Number(user_id));
    res.json({ ok: true, data });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
}
export async function todayGlance(req, res) {
  try {
    const { user_id } = req.query;
    const data = await svc.todayGlance(Number(user_id));
    res.json({ ok: true, data });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
}
export async function daily(req, res) {
  try {
    const { user_id, limit } = req.query;
    const rows = await svc.daily({ user_id: Number(user_id), limit: Number(limit) || 60 });
    res.json({ ok: true, rows });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
}
export async function rollup7(req, res) {
  try {
    const { user_id } = req.query;
    const data = await svc.rollup7(Number(user_id));
    res.json({ ok: true, data });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
}
