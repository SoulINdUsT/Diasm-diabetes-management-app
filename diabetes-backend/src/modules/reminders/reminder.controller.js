import * as svc from './reminder.service.js';

export const create  = async (req,res,next)=>{try{res.json(await svc.create(req.user.id, req.body));}catch(e){next(e)}};
export const list    = async (req,res,next)=>{try{res.json(await svc.list(req.user.id, req.query));}catch(e){next(e)}};
export const get     = async (req,res,next)=>{try{res.json(await svc.get(req.user.id, req.params.id));}catch(e){next(e)}};
export const update  = async (req,res,next)=>{try{res.json(await svc.update(req.user.id, req.params.id, req.body));}catch(e){next(e)}};
export const remove  = async (req,res,next)=>{try{res.json(await svc.remove(req.user.id, req.params.id));}catch(e){next(e)}};
export const toggle  = async (req,res,next)=>{try{res.json(await svc.toggle(req.user.id, req.params.id));}catch(e){next(e)}};
export const snooze  = async (req,res,next)=>{try{res.json(await svc.snooze(req.user.id, req.params.id, req.body.minutes));}catch(e){next(e)}};
export const events  = async (req,res,next)=>{try{res.json(await svc.events(req.user.id, req.params.id, req.query));}catch(e){next(e)}};
