// src/modules/rightpath/rightpath.controller.js
import { pool } from '../../config/db.js';

// -------- helpers --------
// ✅ STRICT: never fall back to user 1
const uid = (req) => {
  const id = req.user?.id;
  if (!id) return null;
  return Number(id);
};

const num = (x) => (x == null ? null : Number(x));
const isBool = (v) => typeof v === 'boolean';

const logSqlError = (e) => {
  if (e && e.sqlMessage) {
    console.error('--- SQL ERROR (right_path_days) -----');
    console.error('Message :', e.sqlMessage);
    if (e.errno) console.error('Errno   :', e.errno);
    if (e.code) console.error('Code    :', e.code);
    if (e.sql) console.error('Query   :', e.sql);
    console.error('-------------------------------------');
  } else {
    console.error(e);
  }
};

// -------- validation + scoring --------
function validateInput(body) {
  const errors = [];

  const walkMinutes = num(body.walkMinutes);
  const hydrationGlasses = num(body.hydrationGlasses);
  const mealsOnTime = body.mealsOnTime;
  const sleepHours = num(body.sleepHours);

  if (!Number.isFinite(walkMinutes) || walkMinutes < 0 || walkMinutes > 600) {
    errors.push('invalid_walkMinutes');
  }
  if (
    !Number.isFinite(hydrationGlasses) ||
    hydrationGlasses < 0 ||
    hydrationGlasses > 30
  ) {
    errors.push('invalid_hydrationGlasses');
  }
  if (!isBool(mealsOnTime)) {
    errors.push('invalid_mealsOnTime');
  }
  if (!Number.isFinite(sleepHours) || sleepHours < 0 || sleepHours > 24) {
    errors.push('invalid_sleepHours');
  }

  return {
    ok: errors.length === 0,
    errors,
    values: {
      walkMinutes,
      hydrationGlasses,
      mealsOnTime,
      sleepHours,
    },
  };
}

/**
 * Scoring logic (weights sum to 100):
 * - Walking:   25%
 * - Hydration: 20%
 * - Meals:     20%
 * - Glucose:   15%
 * - Sleep:     20%
 *
 * Partial credit:
 * - Walk 30+ min  -> full 25; 15–29 -> 12.5; <15 -> 0
 * - Hydration 6+  -> full 20; 4–5  -> 10;   <4  -> 0
 * - Sleep 7+ h    -> full 20; 6–<7 -> 10;   <6  -> 0
 */
function computeScore(vals, glucoseChecked) {
  let score = 0;

  // walking
  if (vals.walkMinutes >= 30) score += 25;
  else if (vals.walkMinutes >= 15) score += 12.5;

  // hydration
  if (vals.hydrationGlasses >= 6) score += 20;
  else if (vals.hydrationGlasses >= 4) score += 10;

  // meals on time
  if (vals.mealsOnTime) score += 20;

  // glucose check
  if (glucoseChecked) score += 15;

  // sleep
  if (vals.sleepHours >= 7) score += 20;
  else if (vals.sleepHours >= 6) score += 10;

  return Math.round(score);
}

function computeStatus(score) {
  if (score >= 80) return 'ON_TRACK';
  if (score >= 50) return 'ALMOST';
  return 'NEEDS_CARE';
}

/**
 * Build English/Bangla messages based on lifestyle issues + glucoseInfo.
 * glucoseInfo: { checked: boolean, lastMgdl: number|null }
 */
function buildMessages(vals, glucoseChecked, score, glucoseInfo) {
  const issuesEn = [];
  const issuesBn = [];

  if (vals.walkMinutes < 30) {
    issuesEn.push('walking');
    issuesBn.push('হাঁটা');
  }
  if (vals.hydrationGlasses < 6) {
    issuesEn.push('water intake');
    issuesBn.push('পানি পান');
  }
  if (!vals.mealsOnTime) {
    issuesEn.push('meal timing');
    issuesBn.push('খাবারের সময় মেনে চলা');
  }
  if (!glucoseChecked) {
    issuesEn.push('glucose checking');
    issuesBn.push('গ্লুকোজ পরীক্ষা');
  }
  if (vals.sleepHours < 7) {
    issuesEn.push('sleep');
    issuesBn.push('ঘুম');
  }

  let messageEn;
  let messageBn;

  if (score >= 80) {
    if (issuesEn.length === 0) {
      messageEn = 'Great job today. You are on the right path.';
      messageBn = 'আজ খুব ভালো করেছেন। আপনি সঠিক পথে আছেন।';
    } else {
      messageEn = `Good day overall. Just take a bit more care with ${issuesEn.join(
        ', '
      )}.`;
      messageBn = `দিনটা মোটের ওপরে ভালো। শুধু একটু বেশি খেয়াল রাখুন: ${issuesBn.join(
        ', '
      )}।`;
    }
  } else if (score >= 50) {
    messageEn = `You are close to your healthy routine. Focus on improving: ${issuesEn.join(
      ', '
    )}.`;
    messageBn = `আপনি স্বাস্থ্যকর রুটিনের খুব কাছাকাছি। একটু মনোযোগ দিন: ${issuesBn.join(
      ', '
    )}।`;
  } else {
    messageEn = `Today your routine needs more care. Start by improving: ${issuesEn.join(
      ', '
    )}.`;
    messageBn = `আজকের দিনটায় আরও যত্ন দরকার। শুরু করুন এগুলো থেকে: ${issuesBn.join(
      ', '
    )}।`;
  }

  // extra advice based on today's last glucose value
  if (glucoseInfo && glucoseInfo.checked && glucoseInfo.lastMgdl != null) {
    const g = glucoseInfo.lastMgdl;

    if (g < 70) {
      messageEn +=
        ' Your last glucose reading today was low. If you feel shaky, sweaty or weak, take fast-acting carbohydrates (like sugary drink or glucose tablets) and follow your doctor’s advice.';
      messageBn +=
        ' আজ আপনার শেষ গ্লুকোজ রিডিং কম ছিল। যদি কাঁপুনি, ঘাম বা দুর্বল লাগতে থাকে, দ্রুত কাজ করে এমন কার্বোহাইড্রেট (যেমন চিনি মিশ্রিত পানি বা গ্লুকোজ) গ্রহণ করুন এবং ডাক্তারের পরামর্শ অনুসরণ করুন।';
    } else if (g > 180) {
      messageEn +=
        ' Your last glucose reading today was high. Drink water, move gently if you can, and follow your doctor’s plan for high sugar. Try to review your meal and medication timing.';
      messageBn +=
        ' আজ আপনার শেষ গ্লুকোজ রিডিং বেশি ছিল। পানি পান করুন, সম্ভব হলে হালকা হাঁটুন, এবং উচ্চ সুগারের জন্য ডাক্তারের দেওয়া পরামর্শ অনুসরণ করুন। খাবার ও ওষুধের সময় মেনে চলা হয়েছে কি না তা ভেবে দেখুন।';
    }
  }

  return { messageEn, messageBn };
}

// -------- DB helper --------
async function getGlucoseTodayInfo(userId) {
  const [rows] = await pool.execute(
    `SELECT value_mgdl
       FROM metrics_glucose
      WHERE user_id = ?
        AND DATE(measured_at) = CURDATE()
      ORDER BY measured_at DESC
      LIMIT 1`,
    [userId]
  );

  if (!rows.length) {
    return { checked: false, lastMgdl: null };
  }

  const lastMgdl =
    rows[0].value_mgdl != null ? Number(rows[0].value_mgdl) : null;

  return {
    checked: true,
    lastMgdl,
  };
}

// -------- controllers --------

// GET /api/v1/right-path/today
export async function getToday(req, res) {
  try {
    const userId = uid(req);
    if (!userId) {
      return res.status(401).json({ error: 'Missing Authorization header' });
    }

    const [rows] = await pool.execute(
      `SELECT user_id, date, walk_minutes, hydration_glasses,
              meals_on_time, glucose_checked, sleep_hours,
              daily_score, status, message_en, message_bn
         FROM right_path_days
        WHERE user_id = ? AND date = CURDATE()
        LIMIT 1`,
      [userId]
    );

    if (!rows.length) {
      return res.json(null);
    }

    const r = rows[0];
    return res.json({
      userId: r.user_id,
      date: r.date,
      walkMinutes: r.walk_minutes,
      hydrationGlasses: r.hydration_glasses,
      mealsOnTime: !!r.meals_on_time,
      glucoseChecked: !!r.glucose_checked,
      sleepHours: r.sleep_hours != null ? Number(r.sleep_hours) : null,
      dailyScore: r.daily_score,
      status: r.status,
      messageEn: r.message_en,
      messageBn: r.message_bn,
    });
  } catch (e) {
    logSqlError(e);
    return res.status(500).json({ error: 'server_error' });
  }
}

// POST /api/v1/right-path/today
export async function saveToday(req, res) {
  try {
    const userId = uid(req);
    if (!userId) {
      return res.status(401).json({ error: 'Missing Authorization header' });
    }

    // 1) Validate lifestyle inputs
    const { ok, errors, values } = validateInput(req.body || {});
    if (!ok) {
      return res
        .status(400)
        .json({ error: 'validation_error', details: errors });
    }

    // 2) Auto-detect glucose status from today's readings
    const glucoseInfo = await getGlucoseTodayInfo(userId);
    const glucoseChecked = !!(glucoseInfo && glucoseInfo.lastMgdl != null);

    // 3) Compute score + status + messages
    const dailyScore = computeScore(values, glucoseChecked);
    const status = computeStatus(dailyScore);
    const { messageEn, messageBn } = buildMessages(
      values,
      glucoseChecked,
      dailyScore,
      glucoseInfo
    );

    // 4) Upsert today into right_path_days
    await pool.execute(
      `INSERT INTO right_path_days
         (user_id, date, walk_minutes, hydration_glasses, meals_on_time,
          glucose_checked, sleep_hours, daily_score, status, message_en, message_bn)
       VALUES
         (?, CURDATE(), ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         walk_minutes       = VALUES(walk_minutes),
         hydration_glasses  = VALUES(hydration_glasses),
         meals_on_time      = VALUES(meals_on_time),
         glucose_checked    = VALUES(glucose_checked),
         sleep_hours        = VALUES(sleep_hours),
         daily_score        = VALUES(daily_score),
         status             = VALUES(status),
         message_en         = VALUES(message_en),
         message_bn         = VALUES(message_bn)`,
      [
        userId,
        values.walkMinutes,
        values.hydrationGlasses,
        values.mealsOnTime ? 1 : 0,
        glucoseChecked ? 1 : 0,
        values.sleepHours,
        dailyScore,
        status,
        messageEn,
        messageBn,
      ]
    );

    // 5) Return the updated object (what Flutter expects)
    return res.status(201).json({
      userId,
      date: new Date().toISOString().slice(0, 10),
      walkMinutes: values.walkMinutes,
      hydrationGlasses: values.hydrationGlasses,
      mealsOnTime: values.mealsOnTime,
      glucoseChecked,
      sleepHours: values.sleepHours,
      dailyScore,
      status,
      messageEn,
      messageBn,
    });
  } catch (e) {
    logSqlError(e);
    return res.status(500).json({ error: 'server_error' });
  }
}

// GET /api/v1/right-path/history?days=7
export async function getHistory(req, res) {
  try {
    const userId = uid(req);
    if (!userId) {
      return res.status(401).json({ error: 'Missing Authorization header' });
    }

    const daysRaw = parseInt(req.query.days ?? '7', 10);
    const days = Number.isFinite(daysRaw)
      ? Math.min(30, Math.max(1, daysRaw))
      : 7;

    const [rows] = await pool.execute(
      `SELECT date, daily_score, status
         FROM right_path_days
        WHERE user_id = ?
          AND date >= (CURDATE() - INTERVAL ? DAY)
        ORDER BY date DESC`,
      [userId, days]
    );

    const result = rows.map((r) => ({
      date: r.date,
      dailyScore: r.daily_score,
      status: r.status,
    }));

    return res.json(result);
  } catch (e) {
    logSqlError(e);
    return res.status(500).json({ error: 'server_error' });
  }
}

// GET /api/v1/right-path/weekly-summary
export async function getWeeklySummary(req, res) {
  try {
    const userId = uid(req);
    if (!userId) {
      return res.status(401).json({ error: 'Missing Authorization header' });
    }

    // 1) Summary of last 7 days (today + previous 6)
    const [rows] = await pool.execute(
      `SELECT
          COUNT(*)                     AS days_tracked,
          AVG(daily_score)             AS avg_score,
          SUM(status = 'ON_TRACK')     AS on_track_days,
          SUM(status = 'ALMOST')       AS almost_days,
          SUM(status = 'NEEDS_CARE')   AS needs_care_days
       FROM right_path_days
       WHERE user_id = ?
         AND date >= (CURDATE() - INTERVAL 6 DAY)`,
      [userId]
    );

    const stats = rows[0] || {};

    // 2) Did user log weight at least once in last 7 days?
    const [weightRows] = await pool.execute(
      `SELECT COUNT(*) AS cnt
         FROM metrics_weight
        WHERE user_id = ?
          AND measured_at >= (CURDATE() - INTERVAL 6 DAY)`,
      [userId]
    );

    const weightCnt = weightRows?.[0]?.cnt ?? 0;
    const weightCheckedThisWeek = weightCnt > 0;

    // 3) Date range (for clarity)
    const [dateRows] = await pool.execute(
      `SELECT
          (CURDATE() - INTERVAL 6 DAY) AS from_date,
          CURDATE()                    AS to_date`
    );

    const dr = dateRows[0];

    return res.json({
      fromDate: dr.from_date,
      toDate: dr.to_date,
      daysTracked: stats.days_tracked || 0,
      averageScore: stats.avg_score != null ? Math.round(stats.avg_score) : 0,
      onTrackDays: stats.on_track_days || 0,
      almostDays: stats.almost_days || 0,
      needsCareDays: stats.needs_care_days || 0,
      weightCheckedThisWeek,
    });
  } catch (e) {
    logSqlError(e);
    return res.status(500).json({ error: 'server_error' });
  }
}
