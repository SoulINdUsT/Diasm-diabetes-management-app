import * as mdl from './hydration.model.js';

export async function setGoal(user_id, daily_ml) {
  await mdl.upsertGoal(user_id, daily_ml);
  return await mdl.getGoal(user_id);
}
export async function getGoal(user_id) { return await mdl.getGoal(user_id); }

export async function logEvent({ user_id, event_at, volume_ml }) {
  const id = await mdl.addEvent({ user_id, event_at, volume_ml });
  return { id };
}
export async function removeEvent({ id, user_id }) {
  const n = await mdl.deleteEvent({ id, user_id });
  return { removed: !!n };
}
export async function eventsForDay({ user_id, day }) {
  return await mdl.listEventsForDay({ user_id, day });
}

export async function today(user_id) { return await mdl.getToday(user_id); }
export async function todayGlance(user_id) { return await mdl.getTodayGlance(user_id); }
export async function daily({ user_id, limit }) { return await mdl.getDaily({ user_id, limit }); }
export async function rollup7(user_id) { return await mdl.getRollup7(user_id); }
