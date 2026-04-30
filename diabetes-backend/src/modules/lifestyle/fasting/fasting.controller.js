import * as svc from './fasting.service.js';

function ok(res, data) { res.json({ ok: true, data }); }

function fail(res, e) { console.error('[fasting]', e); res.status(400).json({ ok: false, error: e.message }); }

export async function startSession(req, res) {
  try { ok(res, await svc.startSession(req.body)); }
  catch (e) { fail(res, e); }
}

export async function addEvent(req, res) {
  try { ok(res, await svc.addEvent(req.body)); }
  catch (e) { fail(res, e); }
}

export async function endSession(req, res) {
  try { ok(res, await svc.endSession(req.body)); }
  catch (e) { fail(res, e); }
}

export async function getActive(req, res) {
  try { ok(res, { rows: await svc.getActive(req.query.user_id) }); }
  catch (e) { fail(res, e); }
}

export async function getHistory(req, res) {
  try { ok(res, { rows: await svc.getHistory(req.query.user_id) }); }
  catch (e) { fail(res, e); }
}

export async function getRollup(req, res) {
  try { ok(res, { rows: await svc.getRollup(req.query.user_id) }); }
  catch (e) { fail(res, e); }
}

export async function getSummary(req, res) {
  try { ok(res, { rows: await svc.getSummary(req.query.user_id) }); }
  catch (e) { fail(res, e); }
}
