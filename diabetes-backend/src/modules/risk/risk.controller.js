// src/modules/risk/risk.controller.js
// Clean risk controller — safe fallbacks + advisory messages
import { pool } from '../../config/db.js';
import { z } from 'zod';

const isDev = process.env.NODE_ENV !== 'production';

function sendDbError(res, e, fallback = 'Database error') {
  console.error('[DB]', e?.sqlMessage || e?.message || e);
  res.status(500).json({
    error: fallback,
    detail: isDev ? (e?.sqlMessage || e?.message) : undefined,
  });
}

async function columnExists(conn, table, column) {
  const [rows] = await conn.query(
    `SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ?
        AND COLUMN_NAME = ?
      LIMIT 1`,
    [table, column]
  );
  return rows.length > 0;
}

function bandFromScore(total) {
  return total >= 60 ? 'High' : total >= 30 ? 'Moderate' : 'Low';
}

function advisory(locale, band) {
  const en = {
    High:     "Your risk of undiagnosed type 2 diabetes is high. Please arrange a fasting glucose or HbA1c test soon and begin lifestyle changes.",
    Moderate: "Your risk is moderate. Improve diet and activity, and consider a screening test within 1–3 months.",
    Low:      "Your risk is low. Maintain healthy habits and recheck in 6–12 months."
  };
  const bn = {
    High:     "আপনার অজানা টাইপ ২ ডায়াবেটিসের ঝুঁকি বেশি। দ্রুত ফাস্টিং সুগার বা HbA1c টেস্ট করুন এবং জীবনযাপনে পরিবর্তন শুরু করুন।",
    Moderate: "আপনার ঝুঁকি মধ্যম। খাদ্যাভ্যাস ও শারীরিক কর্মকাণ্ড উন্নত করুন এবং ১–৩ মাসের মধ্যে স্ক্রিনিং টেস্ট বিবেচনা করুন।",
    Low:      "আপনার ঝুঁকি কম। সুস্থ অভ্যাস বজায় রাখুন এবং ৬–১২ মাস পর পুনরায় যাচাই করুন।"
  };
  const table = locale === 'bn' ? bn : en;
  return table[band] || table.Low;
}

/* ---------------------- TOOLS ---------------------- */
export async function listTools(_req, res) {
  try {
    const [rows] = await pool.query(
      `SELECT id, code, name, version,
              locale_default AS localeDefault,
              created_at     AS createdAt
       FROM risk_tools
       ORDER BY id ASC`
    );
    res.json(rows);
  } catch (e) {
    sendDbError(res, e, 'Failed to load tools');
  }
}

/* ------------------- QUESTIONS (safe) ------------------- */
/* Uses SELECT * to avoid schema mismatches (no hard-coded 'label') */
export async function listQuestions(req, res) {
  const toolId = Number(req.params.toolId);
  if (!toolId) return res.status(400).json({ error: 'toolId required' });

  try {
    const [qs] = await pool.query(
      'SELECT * FROM risk_questions WHERE tool_id = ? ORDER BY order_no ASC',
      [toolId]
    );
    if (!qs.length) return res.json([]);

    const ids = qs.map(q => q.id);
    const [os] = ids.length
      ? await pool.query(
          `SELECT * FROM risk_options
           WHERE question_id IN (${ids.map(() => '?').join(',')})
           ORDER BY order_no ASC`,
          ids
        )
      : [[]];

    const pickQLabel = q =>
      q.label ?? q.question_label ?? q.q_label ?? q.qCode ?? q.q_code ?? `Q${q.id}`;
    const pickOLabel = o =>
      o.label ?? o.option_label ?? o.o_label ?? o.opt_code ?? `Option ${o.id}`;

    const byQ = Object.fromEntries(
      qs.map(q => [
        q.id,
        {
          id: q.id,
          toolId: q.tool_id ?? toolId,
          qCode: q.q_code ?? null,
          label: pickQLabel(q),
          orderNo: q.order_no ?? 0,
          multi: Boolean(q.multi_select ?? 0),
          options: [],
        },
      ])
    );

    for (const o of os) {
      const host = byQ[o.question_id];
      if (!host) continue;
      host.options.push({
        id: o.id,
        label: pickOLabel(o),
        score: o.score ?? 0,
        orderNo: o.order_no ?? 0,
      });
    }

    res.json(Object.values(byQ));
  } catch (e) {
    sendDbError(res, e, 'Failed to load questions');
  }
}

/* ------------------- SUBMIT (safe) ------------------- */
const SubmitSchema = z.object({
  toolId: z.number(),
  answers: z
    .array(
      z.object({
        questionId: z.number(),
        optionId: z.number().optional(),
        value: z.union([z.string(), z.number()]).optional(), // ignored if column absent
      })
    )
    .min(1, 'answers required'),
});

export async function submitAssessment(req, res) {
  const parsed = SubmitSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const { toolId, answers } = parsed.data;

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // ensure tool exists
    const [[tool]] = await conn.query('SELECT id FROM risk_tools WHERE id=?', [toolId]);
    if (!tool) {
      await conn.rollback();
      return res.status(400).json({ error: `Tool ${toolId} not found` });
    }

    // validate questions belong to tool
    const [qs] = await conn.query('SELECT id FROM risk_questions WHERE tool_id=?', [toolId]);
    const qSet = new Set(qs.map(q => q.id));
    for (const a of answers) {
      if (!qSet.has(a.questionId)) {
        await conn.rollback();
        return res.status(400).json({ error: `questionId ${a.questionId} not in tool ${toolId}` });
      }
    }

    // verify options & gather scores
    const optionIds = answers.map(a => a.optionId).filter(Boolean);
    let scoreByOpt = new Map();
    if (optionIds.length) {
      const [opts] = await conn.query(
        `SELECT id, question_id AS qid, score
           FROM risk_options
          WHERE id IN (${optionIds.map(() => '?').join(',')})`,
        optionIds
      );
      const valid = new Map(); // qid -> Set(optionId)
      for (const r of opts) {
        scoreByOpt.set(r.id, r.score ?? 0);
        if (!valid.has(r.qid)) valid.set(r.qid, new Set());
        valid.get(r.qid).add(r.id);
      }
      for (const a of answers) {
        if (!a.optionId) continue;
        if (!valid.get(a.questionId)?.has(a.optionId)) {
          await conn.rollback();
          return res.status(400).json({ error: `optionId ${a.optionId} not in questionId ${a.questionId}` });
        }
      }
    }

    const total = answers.reduce(
      (s, a) => s + (a.optionId ? (scoreByOpt.get(a.optionId) ?? 0) : 0),
      0
    );
    const band = bandFromScore(total);

    // insert assessment
    const [resAssess] = await conn.query(
      `INSERT INTO risk_assessments (tool_id, total_score, risk_band, submitted_at)
       VALUES (?, ?, ?, NOW())`,
      [toolId, total, band]
    );
    const assessmentId = resAssess.insertId;

    // insert answers (works with/without 'value' column)
    if (answers?.length) {
      const hasValue = await columnExists(conn, 'risk_answers', 'value');
      if (hasValue) {
        const rows = answers.map(a => [assessmentId, a.questionId, a.optionId ?? null, a.value ?? null]);
        await conn.query(
          'INSERT INTO risk_answers (assessment_id, question_id, option_id, value) VALUES ?',
          [rows]
        );
      } else {
        const rows = answers.map(a => [assessmentId, a.questionId, a.optionId ?? null]);
        await conn.query(
          'INSERT INTO risk_answers (assessment_id, question_id, option_id) VALUES ?',
          [rows]
        );
      }
    }

    await conn.commit();
    const message_en = advisory('en', band);
    const message_bn = advisory('bn', band);
    res.status(201).json({ id: assessmentId, toolId, total, band, message: message_en, message_bn });
  } catch (e) {
    await conn.rollback();
    sendDbError(res, e, 'Failed to submit assessment');
  } finally {
    conn.release();
  }
}

/* ------------------- RESULTS ------------------- */
export async function listAssessments(req, res) {
  const limit = Math.min(Number(req.query.limit) || 20, 100);
  try {
    const [rows] = await pool.query(
      `SELECT a.id,
              a.tool_id      AS toolId,
              t.code         AS toolCode,
              t.name         AS toolName,
              a.total_score  AS total,
              a.risk_band    AS band,
              a.submitted_at AS submittedAt
         FROM risk_assessments a
         JOIN risk_tools t ON t.id = a.tool_id
        ORDER BY a.submitted_at DESC
        LIMIT ?`,
      [limit]
    );
    res.json(rows);
  } catch (e) {
    sendDbError(res, e, 'Failed to list assessments');
  }
}

export async function getAssessment(req, res) {
  const id = Number(req.params.id);
  if (!id) return res.status(400).json({ error: 'id required' });

  const conn = await pool.getConnection();
  try {
    const [[a]] = await conn.query(
      `SELECT id, tool_id AS toolId, total_score AS total, risk_band AS band, submitted_at AS submittedAt
         FROM risk_assessments
        WHERE id=?`,
      [id]
    );
    if (!a) return res.status(404).json({ error: 'Not found' });

    const hasValue = await columnExists(conn, 'risk_answers', 'value');
    const hasOptLabel = await columnExists(conn, 'risk_options', 'label');

    const valueSelect = hasValue ? 'ra.value,' : 'NULL AS value,';
    const optionLabelSelect = hasOptLabel
      ? 'ro.label AS optionLabel,'
      : 'oi.label AS optionLabel,';

    const [answers] = await conn.query(
      `SELECT ra.id,
              ra.question_id AS questionId,
              ra.option_id   AS optionId,
              ${valueSelect}
              rq.q_code      AS qCode,
              ${optionLabelSelect}
              ro.score
         FROM risk_answers ra
         LEFT JOIN risk_questions rq ON rq.id = ra.question_id
         LEFT JOIN risk_options  ro ON ro.id = ra.option_id
         LEFT JOIN risk_option_i18n oi ON oi.option_id = ra.option_id AND oi.locale = 'en'
        WHERE ra.assessment_id = ?
        ORDER BY ra.id ASC`,
      [id]
    );

    const message_en = advisory('en', a.band);
    const message_bn = advisory('bn', a.band);
    res.json({ ...a, answers, message: message_en, message_bn });
  } catch (e) {
    sendDbError(res, e, 'Failed to fetch assessment');
  } finally {
    conn.release();
  }
}

export async function getLatestAssessment(_req, res) {
  try {
    const [rows] = await pool.query(
      `SELECT id,
              tool_id      AS toolId,
              total_score  AS total,
              risk_band    AS band,
              submitted_at AS submittedAt
         FROM risk_assessments
        ORDER BY submitted_at DESC
        LIMIT 1`
    );
    const latest = rows[0] || null;
    if (!latest) return res.json(null);
    const message_en = advisory('en', latest.band);
    const message_bn = advisory('bn', latest.band);
    res.json({ ...latest, message: message_en, message_bn });
  } catch (e) {
    sendDbError(res, e, 'Failed to fetch latest assessment');
  }
}
