// src/modules/lifestyle/activity/activity.service.js
import * as mdl from './activity.model.js';

function toInt(v, def = null) {
  if (v === undefined || v === null || v === '') return def;
  const n = Number(v);
  return Number.isFinite(n) ? n : def;
}

// Goals
export async function setGoal(payload) {
  const user_id = toInt(payload.user_id);
  const daily_steps = toInt(payload.daily_steps);
  if (!user_id || !daily_steps) throw new Error('user_id and daily_steps are required');
  await mdl.upsertGoal({ user_id, daily_steps });
  return await mdl.getGoal(user_id);
}

export async function getGoal(user_id) {
  return await mdl.getGoal(toInt(user_id));
}

// Steps
export async function logSteps(body) {
  const user_id = toInt(body.user_id);
  const steps = toInt(body.steps);
  if (!user_id || !steps) throw new Error('user_id and steps are required');
  const id = await mdl.addSteps({
    user_id,
    event_at: body.event_at || null,
    steps,
    source: body.source || 'manual'
  });
  return { id };
}

export async function deleteSteps(id, user_id) {
  return { removed: !!(await mdl.removeSteps(toInt(id), toInt(user_id))) };
}

// Event
export async function logEvent(body) {
  const user_id = toInt(body.user_id);
  if (!user_id) throw new Error('user_id is required');

  const id = await mdl.addEvent({
    user_id,
    event_at: body.event_at || null,
    event_type: body.event_type || 'workout',
    minutes: toInt(body.minutes),
    distance_km: body.distance_km ?? null,
    kcal: body.kcal ?? null,
    source: body.source || 'manual',
    notes: body.notes || null
  });
  return { id };
}

export async function deleteEvent(id, user_id) {
  return { removed: !!(await mdl.removeEvent(toInt(id), toInt(user_id))) };
}

// Reads
export async function getToday(user_id) {
  return await mdl.today(toInt(user_id));
}
export async function getTodayGlance(user_id) {
  return await mdl.todayGlance(toInt(user_id));
}
export async function getDaily(user_id, limit) {
  return await mdl.daily(toInt(user_id), toInt(limit, 60));
}
export async function getRollup7(user_id) {
  return await mdl.rollup7(toInt(user_id));
}
export async function getEventsForDay(user_id, day) {
  return await mdl.eventsForDay(toInt(user_id), day);
}
