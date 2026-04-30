import * as mdl from './fasting.model.js';

function mustInt(v, name) {
  const n = Number(v);
  if (!Number.isInteger(n) || n <= 0) throw new Error(`Invalid ${name}`);
  return n;
}

export async function startSession(payload) {
  const user_id = mustInt(payload.user_id, 'user_id');
  const id = await mdl.startSession({
    user_id,
    start_at: payload.start_at,
    fast_kind: payload.fast_kind,
    protocol: payload.protocol,
    target_hours: payload.target_hours,
    notes: payload.notes,
  });
  return { id };
}

export async function addEvent(payload) {
  const user_id = mustInt(payload.user_id, 'user_id');
  const id = await mdl.addEvent({
    user_id,
    event_at: payload.event_at,
    event_type: payload.event_type,
    value_num: payload.value_num,
    value_text: payload.value_text,
  });
  return { id };
}

export async function endSession(payload) {
  const user_id = mustInt(payload.user_id, 'user_id');
  const changed = await mdl.endSession({
    user_id,
    end_at: payload.end_at,
    reason: payload.reason,
  });
  return { closed: !!changed };
}

export const getActive  = async (user_id) => mdl.getActive(mustInt(user_id, 'user_id'));
export const getHistory = async (user_id) => mdl.getHistory(mustInt(user_id, 'user_id'));
export const getRollup  = async (user_id) => mdl.getRollup(mustInt(user_id, 'user_id'));
export const getSummary = async (user_id) => mdl.getSummary(mustInt(user_id, 'user_id'));
