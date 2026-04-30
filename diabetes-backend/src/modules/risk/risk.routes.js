// src/modules/risk/risk.routes.js
import { Router } from 'express';
import { pool } from '../../config/db.js';
import {
  listTools,
  listQuestions,
  submitAssessment,      // body: { toolId, answers:[{questionId, optionId}] }
  listAssessments,
  getAssessment,
  getLatestAssessment,
} from './risk.controller.js';

// ↓ import the BMI→IDRS mapping controller
import { bmiToIdrsOption } from '../calc/calc.controller.js';

const r = Router();

/* ---------- BASIC ---------- */
r.get('/tools', listTools);
r.get('/tools/:toolId/questions', listQuestions);

r.post('/assessments', submitAssessment);
r.get('/assessments', listAssessments);
r.get('/assessments/latest', getLatestAssessment);
r.get('/assessments/:id', getAssessment);

/* ---------- BMI helper (non-scoring) ----------
   GET /api/v1/risk/bmi-opt?kg=&cm=
   → { kg, cm, bmi, opt_code: 'BMI_UNDER_25' | 'BMI_25_29' | 'BMI_30_PLUS' }
   Use this to pre-select BMI option in the UI.
------------------------------------------------*/
r.get('/bmi-opt', bmiToIdrsOption);

/* ---------- BY-CODE CONVENIENCE ENDPOINT ----------
   Post using q_code/opt_code and we’ll map them to IDs, then reuse submitAssessment.
   Body:
   {
     "toolId": 1,                     // optional; if missing we'll resolve from toolCode or 'IDRS'
     "toolCode": "IDRS",              // optional fallback to resolve toolId
     "answers": [
       {"q_code":"AGE","opt_code":"AGE_18_34"},
       {"q_code":"WAIST","opt_code":"MEN_90_99"},
       {"q_code":"BMI","opt_code":"BMI_25_29"},        // <-- BMI included if you want (score 0)
       {"q_code":"ACTIVITY","opt_code":"SEDENTARY"},
       {"q_code":"FAMILY","opt_code":"ONE_PARENT"}
     ]
   }
   Response: same as POST /assessments (includes message + message_bn)
----------------------------------------------------- */
r.post('/assessments/by-code', async (req, res, next) => {
  try {
    let { toolId, toolCode, answers } = req.body || {};
    if (!Array.isArray(answers) || answers.length === 0) {
      return res.status(400).json({ error: 'answers required' });
    }

    // Resolve toolId if missing
    if (!toolId) {
      const code = toolCode || 'IDRS';
      const [[tool]] = await pool.query('SELECT id FROM risk_tools WHERE code = ? LIMIT 1', [code]);
      if (!tool) return res.status(400).json({ error: `Tool not found for code '${code}'` });
      toolId = tool.id;
    }

    // Fetch question map for this tool
    const [qRows] = await pool.query(
      'SELECT id, q_code FROM risk_questions WHERE tool_id = ?',
      [toolId]
    );
    if (!qRows.length) return res.status(400).json({ error: `No questions for toolId ${toolId}` });

    const qByCode = new Map(qRows.map(q => [String(q.q_code), q.id]));

    // Resolve every (q_code, opt_code) to (questionId, optionId)
    const resolved = [];
    for (const a of answers) {
      const qid = qByCode.get(String(a.q_code));
      if (!qid) {
        return res.status(400).json({ error: `Unknown q_code '${a.q_code}' for toolId ${toolId}` });
      }
      const [[opt]] = await pool.query(
        'SELECT id FROM risk_options WHERE question_id = ? AND opt_code = ? LIMIT 1',
        [qid, String(a.opt_code)]
      );
      if (!opt) {
        return res.status(400).json({ error: `Unknown opt_code '${a.opt_code}' for q_code '${a.q_code}'` });
      }
      resolved.push({ questionId: qid, optionId: opt.id });
    }

    // Reuse the main submit handler with transformed body
    req.body = { toolId, answers: resolved };
    return submitAssessment(req, res, next);
  } catch (e) {
    console.error('[by-code]', e?.sqlMessage || e?.message || e);
    return res.status(500).json({ error: 'Failed to submit by-code' });
  }
});

export default r;
