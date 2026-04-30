import * as model from './reminder.model.js';

const TYPES = new Set(['MEDICATION','HYDRATION','HBA1C','BP','CUSTOM']);

function assertOneOfSchedule(b){
  const t = Array.isArray(b.times_json) && b.times_json.length>0;
  const i = Number.isInteger(b.interval_minutes);
  const r = !!b.rrule;
  if(!t && !i && !r){ const e=new Error('Provide one of: times_json[] | interval_minutes | rrule'); e.status=400; throw e; }
}
function validateBase(b,isCreate=true){
  if(!b||typeof b!=='object'){const e=new Error('Body required'); e.status=400; throw e;}
  if(!TYPES.has(b.type)){const e=new Error('Invalid type'); e.status=400; throw e;}
  if(!b.title||!b.timezone||!b.message_en||!b.message_bn){const e=new Error('title, timezone, message_en, message_bn are required'); e.status=400; throw e;}
  if(isCreate && !b.start_date){const e=new Error('start_date is required'); e.status=400; throw e;}
  assertOneOfSchedule(b);
  if(b.times_json && !Array.isArray(b.times_json)) b.times_json=[];
  if(typeof b.active==='undefined') b.active=1;
  if(typeof b.snooze_minutes==='undefined') b.snooze_minutes=0;
  return b;
}

export const create = async (userId, body)=>{
  const b = validateBase(body,true);
  const id = await model.insert(userId,b);
  return await model.findOne(userId,id);
};
export const list   = async (userId,q)=> model.findAll(userId,q);
export const get    = async (userId,id)=>{ const row=await model.findOne(userId,id); if(!row){const e=new Error('Not found'); e.status=404; throw e;} return row; };
export const update = async (userId,id,body)=>{ const old=await model.findOne(userId,id); if(!old){const e=new Error('Not found'); e.status=404; throw e;} const merged=validateBase({...old,...body},false); await model.update(userId,id,merged); return await model.findOne(userId,id); };
export const remove = async (userId,id)=>{ const n=await model.remove(userId,id); if(!n){const e=new Error('Not found'); e.status=404; throw e;} return {deleted:true}; };
export const toggle = async (userId,id)=>{ const n=await model.toggle(userId,id); if(!n){const e=new Error('Not found'); e.status=404; throw e;} return await model.findOne(userId,id); };
export const snooze = async (userId,id,minutes=0)=>{ minutes=parseInt(minutes,10)||0; if(minutes<0) minutes=0; const n=await model.setSnooze(userId,id,minutes); if(!n){const e=new Error('Not found'); e.status=404; throw e;} return await model.findOne(userId,id); };
export const events = async (userId,id,q={})=>{ const rem=await model.findOne(userId,id); if(!rem){const e=new Error('Not found'); e.status=404; throw e;} return await model.listEvents(id, q.from||null, q.to||null); };
