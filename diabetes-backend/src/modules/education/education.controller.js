// src/modules/education/education.controller.js
import { pool } from '../../config/db.js';
import { ListContentsQuery } from './education.validator.js';
import { translateEduText } from '../../services/translate.gemini.js';

// Helper: normalise lang
function normalizeLang(value) {
  return value === 'bn' ? 'bn' : 'en';
}

// Build absolute media URL from stored filename or relative path
function toPublicMediaUrl(req, mediaUrl) {
  if (!mediaUrl) return null;

  // already absolute (http/https)
  if (/^https?:\/\//i.test(mediaUrl)) return mediaUrl;

  const host = `${req.protocol}://${req.get('host')}`;

  // if DB already stores "/uploads/education/xxx.png"
  if (mediaUrl.startsWith('/')) return `${host}${mediaUrl}`;

  // otherwise assume it's a filename inside uploads/education
  return `${host}/uploads/education/${mediaUrl}`;
}

/**
 * GET /api/v1/education/categories?lang=en|bn
 */
export async function getCategories(req, res, next) {
  const lang = normalizeLang(req.query.lang);

  try {
    const [rows] = await pool.execute(
      `SELECT id, code, name_en, name_bn
       FROM education_categories
       ORDER BY id ASC`,
      []
    );

    const categories = rows.map((c) => ({
      id: c.id,
      code: c.code,
      nameEn: c.name_en,
      nameBn: c.name_bn,
      displayName:
        lang === 'bn'
          ? (c.name_bn && c.name_bn.trim().length ? c.name_bn : c.name_en)
          : c.name_en,
    }));

    res.json({ lang, categories });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/v1/education/contents?lang=en|bn&category=DIABETES_BASICS&q=&limit=&offset=
 */
export async function getContents(req, res, next) {
  const parse = ListContentsQuery.safeParse(req.query);
  if (!parse.success) {
    return res.status(400).json({
      error: 'Validation error',
      details: parse.error.issues ?? [],
    });
  }

  const lang = parse.data.lang ?? 'en';
  const categoryCode = parse.data.category; // optional
  const q = parse.data.q; // optional

  let limit = Number(parse.data.limit ?? 100);
  let offset = Number(parse.data.offset ?? 0);
  if (!Number.isFinite(limit) || limit <= 0) limit = 100;
  if (!Number.isFinite(offset) || offset < 0) offset = 0;

  try {
    const where = [];
    const params = [];

    if (categoryCode) {
      where.push('c.code = ?');
      params.push(categoryCode);
    }

    if (q) {
      where.push(`(
        ec.title_en LIKE ? OR ec.body_en LIKE ? OR
        ec.title_bn LIKE ? OR ec.body_bn LIKE ?
      )`);
      const like = `%${q}%`;
      params.push(like, like, like, like);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const sql = `
      SELECT
        ec.id,
        ec.category_id,
        c.code AS category_code,
        ec.title_en,
        ec.body_en,
        ec.title_bn,
        ec.body_bn,
        ec.media_type,
        COALESCE(ec.media_url, em.media_url) AS media_url,
        ec.created_at
      FROM education_contents ec
      JOIN education_categories c
        ON ec.category_id = c.id
      LEFT JOIN education_media_map em
        ON em.content_id = ec.id
      ${whereSql}
      ORDER BY ec.id ASC
      LIMIT ${limit}
      OFFSET ${offset}
    `;

    const [rows] = await pool.execute(sql, params);

    const items = rows.map((r) => {
      let title = r.title_en;
      let body = r.body_en;

      if (lang === 'bn') {
        // Use stored Bangla if present; otherwise fall back to English.
        if (r.title_bn && r.title_bn.trim().length) {
          title = r.title_bn;
        }
        if (r.body_bn && r.body_bn.trim().length) {
          body = r.body_bn;
        }
      }

      return {
        id: r.id,
        categoryId: r.category_id,
        categoryCode: r.category_code,
        title,
        body,
        titleEn: r.title_en,
        bodyEn: r.body_en,
        titleBn: r.title_bn,
        bodyBn: r.body_bn,
        mediaType: r.media_type,
        mediaUrl: toPublicMediaUrl(req, r.media_url),
        createdAt: r.created_at,
      };
    });

    res.json({
      lang,
      items,
      total: items.length,
      limit,
      offset,
      category: categoryCode ?? null,
      q: q ?? null,
    });
  } catch (err) {
    next(err);
  }
}


/**
 * GET /api/v1/education/contents/:id?lang=en|bn
 *
 * Auto-caches Bangla translation into title_bn/body_bn when missing.
 */
export async function getItemById(req, res, next) {
  const lang = normalizeLang(req.query.lang);
  const id = Number(req.params.id);

  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: 'Invalid id' });
  }

  try {
    const sql = `
      SELECT
        ec.id,
        ec.category_id,
        c.code AS category_code,
        ec.title_en,
        ec.body_en,
        ec.title_bn,
        ec.body_bn,
        ec.media_type,
        COALESCE(ec.media_url, em.media_url) AS media_url,
        ec.created_at
      FROM education_contents ec
      JOIN education_categories c
        ON ec.category_id = c.id
      LEFT JOIN education_media_map em
        ON em.content_id = ec.id
      WHERE ec.id = ?
      LIMIT 1
    `;

    const [rows] = await pool.execute(sql, [id]);

    if (!rows.length) {
      return res.status(404).json({ error: 'Not found' });
    }

    const r = rows[0];

    let title = r.title_en;
    let body = r.body_en;
    let titleBn = r.title_bn;
    let bodyBn = r.body_bn;

    if (lang === 'bn') {
      // Use stored Bangla if present; otherwise show English.
      if (r.title_bn && r.title_bn.trim().length) {
        title = r.title_bn;
      }
      if (r.body_bn && r.body_bn.trim().length) {
        body = r.body_bn;
      }
    }

    res.json({
      id: r.id,
      categoryId: r.category_id,
      categoryCode: r.category_code,
      title,
      body,
      titleEn: r.title_en,
      bodyEn: r.body_en,
      titleBn,
      bodyBn,
      mediaType: r.media_type,
      mediaUrl: toPublicMediaUrl(req, r.media_url),
      createdAt: r.created_at,
      lang,
    });
  } catch (err) {
    next(err);
  }
}
