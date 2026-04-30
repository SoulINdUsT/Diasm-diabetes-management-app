// src/modules/lifestyle/activity/activity.routes.js
import { Router } from 'express';
import * as ctl from './activity.controller.js';

const r = Router();

// goals
r.put('/goal', ctl.putGoal);
r.get('/goal', ctl.getGoal);

// steps
r.post('/steps', ctl.addSteps);
r.delete('/steps/:id', ctl.deleteSteps);

// workout events
r.post('/event', ctl.addEvent);
r.delete('/event/:id', ctl.deleteEvent);

// reads
r.get('/today', ctl.today);
r.get('/today/glance', ctl.todayGlance);
r.get('/daily', ctl.daily);
r.get('/rollup7', ctl.rollup7);
r.get('/events', ctl.eventsForDay);

export default r;
