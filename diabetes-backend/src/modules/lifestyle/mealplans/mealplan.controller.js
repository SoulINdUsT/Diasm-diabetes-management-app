
// src/modules/lifestyle/mealplans/mealplan.controller.js
import * as svc from './mealplan.service.js';
import { maybeTranslate } from '../lifestyle.service.js';

/* ------------------------------------------------------------------ */
/* Helpers                                                            */
/* ------------------------------------------------------------------ */
function toInt(v) {
  const n = Number(v);
  return Number.isInteger(n) ? n : NaN;
}

/* ------------------------------------------------------------------ */
/* NEW: Recommendation endpoint                                       */
/* ------------------------------------------------------------------ */

// GET /lifestyle/mealplans/recommend?target_calories=1450&lang=bn
export async function recommend(req, res, next) {
  try {
    const target = Number(req.query.target_calories);
    if (!target || Number.isNaN(target) || target <= 0) {
      return res
        .status(400)
        .json({ ok: false, error: 'Invalid target_calories' });
    }

    const lang = req.query.lang;
    let result = await svc.recommendTemplatePlan(target);

    // Optional translation of titles
    if (lang && lang !== 'en') {
      if (result.recommended_plan) {
        result.recommended_plan = await maybeTranslate(
          result.recommended_plan,
          lang,
          ['title']
        );
      }
      if (Array.isArray(result.alternatives) && result.alternatives.length) {
        result.alternatives = await Promise.all(
          result.alternatives.map((p) => maybeTranslate(p, lang, ['title']))
        );
      }
    }

    res.json({ ok: true, ...result });
  } catch (e) {
    next(e);
  }
}

/* ------------------------------------------------------------------ */
/* Plans                                                              */
/* ------------------------------------------------------------------ */

// POST /lifestyle/mealplans
export async function create(req, res, next) {
  try {
    const id = await svc.createPlan(req.body);
    res.status(201).json({ ok: true, id });
  } catch (e) {
    next(e);
  }
}

// GET /lifestyle/mealplans
// supports: ?q=&limit=&offset=&type=&is_template=&lang=
export async function list(req, res, next) {
  try {
    const { q, limit, offset, type, is_template, lang } = req.query;

    const out = await svc.searchPlans({
      q: q || undefined,
      type: type || undefined,
      is_template: is_template !== undefined ? Number(is_template) : undefined,
      limit: Number(limit) || 20,
      offset: Number(offset) || 0,
    });

    if (lang && lang !== 'en') {
      out.rows = await Promise.all(
        out.rows.map((p) => maybeTranslate(p, lang, ['title']))
      );
    }

    res.json({ ok: true, ...out });
  } catch (e) {
    next(e);
  }
}

// GET /lifestyle/mealplans/templates
export async function listTemplates(req, res, next) {
  try {
    // reuse list() with is_template=1
    req.query.is_template = '1';
    return list(req, res, next);
  } catch (e) {
    next(e);
  }
}

// GET /lifestyle/mealplans/:id
export async function getOne(req, res, next) {
  try {
    const id = toInt(req.params.id);
    if (!id)
      return res.status(400).json({ ok: false, error: 'Invalid plan id' });

    const lang = req.query.lang;
    let data = await svc.getPlan(id);
    if (!data)
      return res.status(404).json({ ok: false, error: 'Not found' });

    if (lang && lang !== 'en') {
      data = await maybeTranslate(data, lang, ['title']);
    }

    res.json({ ok: true, data });
  } catch (e) {
    next(e);
  }
}

// PATCH /lifestyle/mealplans/:id
export async function update(req, res, next) {
  try {
    const id = toInt(req.params.id);
    if (!id)
      return res.status(400).json({ ok: false, error: 'Invalid plan id' });

    const n = await svc.editPlan(id, req.body);
    if (!n)
      return res
        .status(404)
        .json({ ok: false, error: 'Not found or unchanged' });

    const data = await svc.getPlan(id);
    res.json({ ok: true, data });
  } catch (e) {
    next(e);
  }
}

// DELETE /lifestyle/mealplans/:id
export async function remove(req, res, next) {
  try {
    const id = toInt(req.params.id);
    if (!id)
      return res.status(400).json({ ok: false, error: 'Invalid plan id' });

    const n = await svc.removePlan(id);
    if (!n)
      return res.status(404).json({ ok: false, error: 'Not found' });

    res.json({ ok: true, removed: true });
  } catch (e) {
    next(e);
  }
}

/* ------------------------------------------------------------------ */
/* Items                                                              */
/* ------------------------------------------------------------------ */

// GET /lifestyle/mealplans/:id/items
// Returns grouped items + totals from svc.getPlan()
export async function listItems(req, res, next) {
  try {
    const id = toInt(req.params.id);
    if (!id)
      return res.status(400).json({ ok: false, error: 'Invalid plan id' });

    const plan = await svc.getPlan(id);
    if (!plan)
      return res.status(404).json({ ok: false, error: 'Not found' });

    res.json({
      ok: true,
      items_by_meal: plan.items_by_meal || [],
      totals: plan.totals || null,
    });
  } catch (e) {
    next(e);
  }
}

// POST /lifestyle/mealplans/:id/items
export async function addItem(req, res, next) {
  try {
    const id = toInt(req.params.id);
    if (!id)
      return res.status(400).json({ ok: false, error: 'Invalid plan id' });

    const itemId = await svc.addItem(id, req.body);
    res.status(201).json({ ok: true, id: itemId });
  } catch (e) {
    next(e);
  }
}

// PATCH /lifestyle/mealplans/items/:itemId
export async function editItem(req, res, next) {
  try {
    const itemId = toInt(req.params.itemId);
    if (!itemId)
      return res.status(400).json({ ok: false, error: 'Invalid item id' });

    const n = await svc.editItem(itemId, req.body);
    if (!n)
      return res
        .status(404)
        .json({ ok: false, error: 'Not found or unchanged' });

    res.json({ ok: true, updated: true });
  } catch (e) {
    next(e);
  }
}

// DELETE /lifestyle/mealplans/items/:itemId
export async function removeItem(req, res, next) {
  try {
    const itemId = toInt(req.params.itemId);
    if (!itemId)
      return res.status(400).json({ ok: false, error: 'Invalid item id' });

    const n = await svc.removeItem(itemId);
    if (!n)
      return res.status(404).json({ ok: false, error: 'Not found' });

    res.json({ ok: true, removed: true });
  } catch (e) {
    next(e);
  }
}

/* ------------------------------------------------------------------ */
/* User ↔ Plan assignments                                            */
/* ------------------------------------------------------------------ */

// POST /lifestyle/mealplans/assign
// Body: { user_id, meal_plan_id, start_date?, active? }
export async function assignToUser(req, res, next) {
  try {
    const id = await svc.assignPlanToUser(req.body);
    res.status(201).json({ ok: true, id });
  } catch (e) {
    next(e);
  }
}

// GET /lifestyle/mealplans/user/:userId
export async function listUserPlans(req, res, next) {
  try {
    const userId = toInt(req.params.userId);
    if (!userId)
      return res.status(400).json({ ok: false, error: 'Invalid user id' });

    const plans = await svc.getUserPlans(userId);
    res.json({ ok: true, plans });
  } catch (e) {
    next(e);
  }
}

// DELETE /lifestyle/mealplans/assign/:assignmentId
export async function unassign(req, res, next) {
  try {
    const assignmentId = toInt(req.params.assignmentId);
    if (!assignmentId)
      return res
        .status(400)
        .json({ ok: false, error: 'Invalid assignment id' });

    const n = await svc.unassignPlan(assignmentId);
    if (!n)
      return res.status(404).json({ ok: false, error: 'Not found' });

    res.json({ ok: true, removed: true });
  } catch (e) {
    next(e);
  }
}
