import { Router } from 'express';
import {
  setGoal, getGoal,
  addEvent, deleteEvent, listEventsForDay,
  today, todayGlance, daily, rollup7
} from './hydration.controller.js';

const r = Router();

// goals
r.put('/goal', setGoal);
r.get('/goal', getGoal);

// events
r.post('/event', addEvent);
r.delete('/event/:id', deleteEvent);
r.get('/events', listEventsForDay); // ?user_id=8&day=YYYY-MM-DD

// summaries (views)
r.get('/today', today);                 // ?user_id=
r.get('/today/glance', todayGlance);    // ?user_id=
r.get('/daily', daily);                 // ?user_id=&limit=60
r.get('/rollup7', rollup7);             // ?user_id=

export default r;
