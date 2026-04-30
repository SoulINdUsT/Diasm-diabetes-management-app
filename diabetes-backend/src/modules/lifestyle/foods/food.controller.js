
// src/modules/lifestyle/foods/food.controller.js
import * as svc from './food.service.js';
import { translateFoodName } from '../../../services/translate.gemini.js';

export async function create(req, res, next) {
  try {
    res.status(201).json({ ok: true, data: await svc.addFood(req.body) });
  } catch (e) {
    next(e);
  }
}

export async function list(req, res, next) {
  try {
    const { q, limit, offset, order, lang } = req.query;

    const result = await svc.searchFoods({
      q,
      limit: Number(limit) || 20,
      offset: Number(offset) || 0,
      order
    });

    if (lang && lang !== 'en') {
      for (const item of result.rows) {
        item.name_en = await translateFoodName(item.name_en);

        if (item.name_bn) {
          item.name_bn = await translateFoodName(item.name_bn);
        }
      }
    }

    res.json({ ok: true, ...result });
  } catch (e) {
    next(e);
  }
}

export async function getOne(req, res, next) {
  try {
    const food = await svc.getFood(Number(req.params.id));
    if (!food) return res.status(404).json({ ok: false, error: 'Not found' });

    const lang = req.query.lang;

    if (lang && lang !== 'en') {
      food.name_en = await translateFoodName(food.name_en);
      if (food.name_bn) {
        food.name_bn = await translateFoodName(food.name_bn);
      }
    }

    res.json({ ok: true, data: food });
  } catch (e) {
    next(e);
  }
}

export async function update(req, res, next) {
  try {
    res.json({ ok: true, data: await svc.editFood(Number(req.params.id), req.body) });
  } catch (e) {
    next(e);
  }
}

export async function remove(req, res, next) {
  try {
    res.json({ ok: true, removed: !!(await svc.removeFood(Number(req.params.id))) });
  } catch (e) {
    next(e);
  }
}

export async function listPortions(req, res, next) {
  try {
    res.json({ ok: true, portions: await svc.getFood(Number(req.params.id)).then(f => f?.portions || []) });
  } catch (e) {
    next(e);
  }
}

export async function addPortion(req, res, next) {
  try {
    res.status(201).json({ ok: true, ...(await svc.addPortion(Number(req.params.id), req.body)) });
  } catch (e) {
    next(e);
  }
}

export async function editPortion(req, res, next) {
  try {
    res.json({ ok: true, ...(await svc.editPortion(Number(req.params.portionId), req.body)) });
  } catch (e) {
    next(e);
  }
}

export async function removePortion(req, res, next) {
  try {
    res.json({ ok: true, ...(await svc.removePortion(Number(req.params.portionId))) });
  } catch (e) {
    next(e);
  }
}
