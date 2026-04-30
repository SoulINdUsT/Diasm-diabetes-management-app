
// scripts/translate_education_bn.js
// Run with: node scripts/translate_education_bn.js

import 'dotenv/config';
import { pool } from '../src/config/db.js';
import { GoogleGenAI, ApiError } from '@google/genai';

const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
  console.error('GEMINI_API_KEY missing in .env');
  process.exit(1);
}

const MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
const ai = new GoogleGenAI({ apiKey });

// Safer for low RPD: fewer API calls
const BATCH_SIZE = 25;     // 99 items -> ~4 requests
const COOLDOWN_MS = 8000;  // keeps RPM safe (<=5/min)

async function fetchPendingContents() {
  const [rows] = await pool.execute(
    `
    SELECT id, title_en, body_en, title_bn, body_bn
    FROM education_contents
    WHERE
      (title_bn IS NULL OR TRIM(title_bn) = '')
      OR (body_bn IS NULL OR TRIM(body_bn) = '')
    ORDER BY id ASC
  `
  );
  return rows;
}

function buildPrompt(batch) {
  const entriesText = batch
    .map(
      (r, idx) => `
ENTRY ${idx + 1}
ID: ${r.id}
TITLE_EN: """${r.title_en}"""
BODY_EN: """${r.body_en}"""
`
    )
    .join('\n');

  return `
You are a professional medical translator.

TASK:
Translate the following patient education entries into Bangla (Bangladesh).

For EACH entry you MUST produce:
- title_bn: Bangla translation of TITLE_EN
- body_bn: Bangla translation of BODY_EN

OUTPUT RULES (VERY IMPORTANT):
- Output ONLY valid JSON.
- JSON MUST be an array.
- Each element MUST be of the form:
  { "id": <number>, "title_bn": "<Bangla>", "body_bn": "<Bangla>" }
- Do NOT include any extra keys.
- Do NOT include any English text in values.
- Do NOT include comments, explanations, or surrounding text.
- The "id" field MUST match the given ID.

ENTRIES:
${entriesText}
`.trim();
}

async function callGeminiForBatch(batch) {
  const prompt = buildPrompt(batch);

  try {
    const response = await ai.models.generateContent({
      model: MODEL,
      contents: [
        {
          role: 'user',
          parts: [{ text: prompt }],
        },
      ],
    });

    let raw = (response.text || '').trim();
    if (!raw) throw new Error('Empty response from Gemini');

    // Remove Markdown code fences if Gemini adds them
    raw = raw
      .replace(/^```json\s*/i, '')
      .replace(/^```\s*/i, '')
      .replace(/```$/i, '')
      .trim();

    let json;
    try {
      json = JSON.parse(raw);
    } catch (e) {
      console.error('Failed to parse JSON from Gemini. Raw output:');
      console.error(raw);
      throw e;
    }

    if (!Array.isArray(json)) {
      throw new Error('Gemini output is not an array');
    }

    return json;
  } catch (err) {
    if (err instanceof ApiError) {
      console.error(
        'Gemini ApiError:',
        err.status,
        JSON.stringify(err.response, null, 2)
      );
    } else {
      console.error('Gemini Error:', err?.message || err);
    }
    throw err;
  }
}

async function updateDbWithTranslations(translations) {
  for (const t of translations) {
    const id = Number(t.id);
    const titleBn = (t.title_bn || '').trim();
    const bodyBn = (t.body_bn || '').trim();

    if (!id || !titleBn || !bodyBn) {
      console.warn('Skipping invalid translation entry:', t);
      continue;
    }

    try {
      await pool.execute(
        `
        UPDATE education_contents
        SET
          title_bn = ?,
          body_bn  = ?
        WHERE id = ?
      `,
        [titleBn, bodyBn, id]
      );
      console.log(`Updated content id=${id}`);
    } catch (e) {
      console.error(`Failed to update DB for id=${id}:`, e.message || e);
    }
  }
}

async function main() {
  try {
    const rows = await fetchPendingContents();
    console.log(`Found ${rows.length} contents missing Bangla.`);

    if (!rows.length) {
      console.log('Nothing to translate. Exiting.');
      process.exit(0);
    }

    for (let i = 0; i < rows.length; i += BATCH_SIZE) {
      const batch = rows.slice(i, i + BATCH_SIZE);
      console.log(
        `Translating batch ${i / BATCH_SIZE + 1} (${batch[0].id}..${batch[batch.length - 1].id})`
      );

      try {
        const translations = await callGeminiForBatch(batch);
        await updateDbWithTranslations(translations);
      } catch (err) {
        console.error('Batch failed. Moving to next batch.', err?.message || err);
      }

      if (i + BATCH_SIZE < rows.length) {
        console.log(`Cooldown ${COOLDOWN_MS / 1000}s to respect rate limit...`);
        await new Promise((resolve) => setTimeout(resolve, COOLDOWN_MS));
      }
    }
  } catch (err) {
    console.error('Fatal error in translation script:', err?.message || err);
  } finally {
    await pool.end();
    console.log('Done.');
  }
}

main();
