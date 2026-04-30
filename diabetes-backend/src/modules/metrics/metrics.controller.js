
// src/modules/metrics/metrics.controller.js
import { pool } from '../../config/db.js';

// -------- helpers --------
const asDT = (v) => {
  if (!v) return new Date().toISOString().slice(0, 19).replace('T', ' ');
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().slice(0, 19).replace('T', ' ');
};
const num = (x) => (x == null ? null : Number(x));
const within = (n, a, b) => Number.isFinite(n) && n >= a && n <= b;

const okWeight = (b) => {
  const w = num(b.weight_kg), h = num(b.height_cm);
  return within(w, 20, 350) && (h == null || within(h, 80, 250));
};

const okGlucose = (b) =>
  within(num(b.value_mgdl), 20, 700) &&
  ['FBS', 'RBS', 'PP2', 'BeforeMeal', 'AfterMeal', 'Bedtime', 'Custom'].includes(
    b.kind || 'RBS'
  );

const okA1c = (b) => within(num(b.hba1c_percent), 3.0, 20.0);

const okBP = (b) =>
  within(num(b.sys_mmHg), 60, 260) &&
  within(num(b.dia_mmHg), 30, 160) &&
  (b.pulse_bpm == null || within(num(b.pulse_bpm), 20, 220)) &&
  ['Sitting', 'Standing', 'Lying', 'Unknown'].includes(b.posture || 'Unknown');

const okLipids = (b) => {
  const good = (v, a, b2) => (v == null || v === '' ? true : within(num(v), a, b2));
  return (
    good(b.total_mgdl, 50, 500) &&
    good(b.ldl_mgdl, 10, 400) &&
    good(b.hdl_mgdl, 5, 150) &&
    good(b.tg_mgdl, 20, 1500)
  );
};

const okSteps = (b) =>
  within(num(b.steps), 0, 200000) &&
  (b.duration_min == null || within(num(b.duration_min), 0, 1440)) &&
  (b.calories_kcal == null || within(num(b.calories_kcal), 0, 20000));

// ✅ FIX: remove fallback-to-1
const uid = (req) => req.user?.id;

// ✅ helper: consistent 401
const requireUid = (req, res) => {
  const id = uid(req);
  if (!id) {
    res.status(401).json({ error: 'Missing Authorization header' });
    return null;
  }
  return id;
};

const logSqlError = (e) => {
  if (e && e.sqlMessage) {
    console.error('--- SQL ERROR -----------------------');
    console.error('Message :', e.sqlMessage);
    if (e.errno) console.error('Errno   :', e.errno);
    if (e.code) console.error('Code    :', e.code);
    if (e.sql) console.error('Query   :', e.sql);
    console.error('-------------------------------------');
  } else {
    console.error(e);
  }
};

// -------- debug endpoint to verify DB connectivity --------
export async function debugPingDb(_req, res) {
  try {
    const [rows] = await pool.execute('SELECT 1 AS ok');
    res.json(rows[0]);
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'db_error' });
  }
}

// ================== INSERTS ==================
export async function addWeight(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const b = req.body || {};
    if (!okWeight(b)) return res.status(400).json({ error: 'Invalid weight/height' });
    const measured_at = asDT(b.measured_at);
    if (!measured_at) return res.status(400).json({ error: 'Invalid measured_at' });

    await pool.execute(
      `INSERT INTO metrics_weight (user_id, measured_at, weight_kg, height_cm, source, note)
       VALUES (?,?,?,?,?,?)`,
      [userId, measured_at, num(b.weight_kg), num(b.height_cm), b.source || 'manual', b.note ?? null]
    );
    res.status(201).json({ ok: true });
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

export async function addGlucose(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const b = req.body || {};
    if (!okGlucose(b)) return res.status(400).json({ error: 'Invalid glucose/kind' });
    const measured_at = asDT(b.measured_at);
    if (!measured_at) return res.status(400).json({ error: 'Invalid measured_at' });

    await pool.execute(
      `INSERT INTO metrics_glucose (user_id, measured_at, kind, value_mgdl, context, insulin_units, source, note)
       VALUES (?,?,?,?,?,?,?,?)`,
      [userId, measured_at, b.kind || 'RBS', num(b.value_mgdl), b.context ?? null, num(b.insulin_units), b.source || 'manual', b.note ?? null]
    );
    res.status(201).json({ ok: true });
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

export async function addA1c(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const b = req.body || {};
    if (!okA1c(b)) return res.status(400).json({ error: 'Invalid hba1c_percent' });
    const measured_at = asDT(b.measured_at);
    if (!measured_at) return res.status(400).json({ error: 'Invalid measured_at' });

    await pool.execute(
      `INSERT INTO metrics_hba1c (user_id, measured_at, hba1c_percent, lab_name, source, note)
       VALUES (?,?,?,?,?,?)`,
      [userId, measured_at, num(b.hba1c_percent), b.lab_name ?? null, b.source || 'manual', b.note ?? null]
    );
    res.status(201).json({ ok: true });
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

export async function addBP(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const b = req.body || {};
    if (!okBP(b)) return res.status(400).json({ error: 'Invalid BP fields' });
    const measured_at = asDT(b.measured_at);
    if (!measured_at) return res.status(400).json({ error: 'Invalid measured_at' });

    await pool.execute(
      `INSERT INTO metrics_bp (user_id, measured_at, sys_mmHg, dia_mmHg, pulse_bpm, posture, source, note)
       VALUES (?,?,?,?,?,?,?,?)`,
      [userId, measured_at, num(b.sys_mmHg), num(b.dia_mmHg), num(b.pulse_bpm), b.posture || 'Unknown', b.source || 'manual', b.note ?? null]
    );
    res.status(201).json({ ok: true });
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

export async function addLipids(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const b = req.body || {};
    if (!okLipids(b)) return res.status(400).json({ error: 'Invalid lipid ranges' });
    const measured_at = asDT(b.measured_at);
    if (!measured_at) return res.status(400).json({ error: 'Invalid measured_at' });

    await pool.execute(
      `INSERT INTO metrics_cholesterol (user_id, measured_at, total_mgdl, ldl_mgdl, hdl_mgdl, tg_mgdl, source, note)
       VALUES (?,?,?,?,?,?,?,?)`,
      [userId, measured_at, num(b.total_mgdl), num(b.ldl_mgdl), num(b.hdl_mgdl), num(b.tg_mgdl), b.source || 'manual', b.note ?? null]
    );
    res.status(201).json({ ok: true });
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

export async function addSteps(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const b = req.body || {};
    if (!okSteps(b)) return res.status(400).json({ error: 'Invalid steps/duration/calories' });

    const measured_at = b.measured_at ? asDT(b.measured_at) : null;
    const day_date = b.day_date
      ? b.day_date
      : measured_at
      ? measured_at.slice(0, 10)
      : new Date().toISOString().slice(0, 10);

    await pool.execute(
      `INSERT INTO metrics_steps (user_id, day_date, measured_at, steps, duration_min, calories_kcal, source, note)
       VALUES (?,?,?,?,?,?,?,?)`,
      [userId, day_date, measured_at, num(b.steps), num(b.duration_min), num(b.calories_kcal), b.source || 'manual', b.note ?? null]
    );
    res.status(201).json({ ok: true });
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

// ================== LISTS ==================
export async function listWeight(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const page = Math.max(1, parseInt(req.query.page ?? '1', 10));
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit ?? '20', 10)));
    const offset = (page - 1) * limit;
    const from = req.query.from ? `${req.query.from} 00:00:00` : null;
    const to = req.query.to ? `${req.query.to} 23:59:59` : null;

    const where = ['`user_id` = ?'];
    const args = [userId];
    if (from && to) {
      where.push('`measured_at` BETWEEN ? AND ?');
      args.push(from, to);
    }

    const sql = `
      SELECT id,user_id,measured_at,weight_kg,height_cm,bmi,source,note,created_at,updated_at
      FROM \`metrics_weight\`
      WHERE ${where.join(' AND ')}
      ORDER BY \`measured_at\` DESC
      LIMIT ${limit} OFFSET ${offset}
    `;

    const [rows] = await pool.execute(sql, args);
    res.json({ page, limit, rows });
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

export async function listGlucose(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const page = Math.max(1, parseInt(req.query.page ?? '1', 10));
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit ?? '20', 10)));
    const offset = (page - 1) * limit;
    const from = req.query.from ? `${req.query.from} 00:00:00` : null;
    const to = req.query.to ? `${req.query.to} 23:59:59` : null;

    const where = ['`user_id` = ?'];
    const args = [userId];
    if (from && to) {
      where.push('`measured_at` BETWEEN ? AND ?');
      args.push(from, to);
    }

    const sql = `
      SELECT id,user_id,measured_at,kind,value_mgdl,value_mmoll,context,insulin_units,source,note,created_at,updated_at
      FROM \`metrics_glucose\`
      WHERE ${where.join(' AND ')}
      ORDER BY \`measured_at\` DESC
      LIMIT ${limit} OFFSET ${offset}
    `;

    const [rows] = await pool.execute(sql, args);
    res.json({ page, limit, rows });
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

// ================== LATEST (HOME) ==================
export async function getLatestGlucose(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const [rows] = await pool.execute(
      `SELECT
         id,user_id,measured_at,kind,value_mgdl,value_mmoll,context,insulin_units,source,note,created_at,updated_at
       FROM metrics_glucose
       WHERE user_id = ?
       ORDER BY measured_at DESC
       LIMIT 1`,
      [userId]
    );

    res.json(rows[0] || null);
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

// ================== SUMMARIES ==================
export async function glucoseDailySeries(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const { from, to } = req.query;
    if (!from || !to) return res.status(400).json({ error: 'from & to required' });

    const [rows] = await pool.execute(
      `SELECT DATE(measured_at) AS day, ROUND(AVG(value_mgdl),1) AS avg_mgdl
       FROM metrics_glucose
       WHERE user_id = ? AND measured_at BETWEEN CONCAT(?,' 00:00:00') AND CONCAT(?,' 23:59:59')
       GROUP BY DATE(measured_at) ORDER BY day`,
      [userId, from, to]
    );
    res.json(rows);
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

export async function stepsWeekly(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const weeks = Math.max(1, parseInt(req.query.weeks ?? '8', 10));
    const [rows] = await pool.execute(
      `SELECT
         YEARWEEK(COALESCE(measured_at, CONCAT(day_date,' 00:00:00')), 3) AS iso_week,
         SUM(steps) AS week_steps
       FROM metrics_steps
       WHERE user_id = ?
         AND COALESCE(measured_at, CONCAT(day_date,' 00:00:00')) >= UTC_TIMESTAMP() - INTERVAL ? WEEK
       GROUP BY YEARWEEK(COALESCE(measured_at, CONCAT(day_date,' 00:00:00')), 3)
       ORDER BY iso_week`,
      [userId, weeks]
    );
    res.json(rows);
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

export async function weightDailySeries(req, res) {
  try {
    const userId = requireUid(req, res);
    if (!userId) return;

    const [rows] = await pool.execute(
      `SELECT day, weight_kg, bmi
       FROM v_weight_daily
       WHERE user_id = ?
       ORDER BY day`,
      [userId]
    );
    res.json(rows);
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}

export async function dashboardSnapshot(req, res) {
  try {
    const id = requireUid(req, res);
    if (!id) return;

    const [rows] = await pool.execute(
      `SELECT
        (SELECT weight_kg
           FROM metrics_weight
           WHERE user_id = ?
           ORDER BY measured_at DESC
           LIMIT 1) AS last_weight,

        (SELECT bmi
           FROM metrics_weight
           WHERE user_id = ?
           ORDER BY measured_at DESC
           LIMIT 1) AS last_bmi,

        (SELECT value_mgdl
           FROM metrics_glucose
           WHERE user_id = ?
           ORDER BY measured_at DESC
           LIMIT 1) AS last_glucose,

        (SELECT CONCAT(sys_mmHg,'/',dia_mmHg)
           FROM metrics_bp
           WHERE user_id = ?
           ORDER BY measured_at DESC
           LIMIT 1) AS last_bp,

        (SELECT steps
           FROM metrics_steps
           WHERE user_id = ?
           ORDER BY COALESCE(day_date, DATE(measured_at)) DESC,
                    measured_at DESC
           LIMIT 1) AS last_steps,

        (SELECT hba1c_percent
           FROM metrics_hba1c
           WHERE user_id = ?
           ORDER BY measured_at DESC
           LIMIT 1) AS last_hba1c,

        (SELECT total_mgdl
           FROM metrics_cholesterol
           WHERE user_id = ?
           ORDER BY measured_at DESC
           LIMIT 1) AS last_chol_total,

        (SELECT hdl_mgdl
           FROM metrics_cholesterol
           WHERE user_id = ?
           ORDER BY measured_at DESC
           LIMIT 1) AS last_chol_hdl,

        (SELECT ldl_mgdl
           FROM metrics_cholesterol
           WHERE user_id = ?
           ORDER BY measured_at DESC
           LIMIT 1) AS last_chol_ldl
      `,
      [id, id, id, id, id, id, id, id, id]
    );

    res.json(rows[0] || {});
  } catch (e) {
    logSqlError(e);
    res.status(500).json({ error: 'server_error' });
  }
}
