// ESM router
import { Router } from 'express';
import * as c from './reminder.controller.js';
import { authRequired } from '../auth/auth.middleware.js';

const r = Router();

// ✅ Apply auth to ALL reminder routes
r.use(authRequired);

r.post('/', c.create);
r.get('/', c.list);
r.get('/:id', c.get);
r.put('/:id', c.update);
r.delete('/:id', c.remove);
r.post('/:id/toggle', c.toggle);
r.post('/:id/snooze', c.snooze);
r.get('/:id/events', c.events);

export default r; // ✅ default export for app.js
