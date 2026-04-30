
// src/services/translate.gemini.js
import { GoogleGenAI, ApiError } from '@google/genai';

const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
  console.error('[translate.gemini] FATAL: GEMINI_API_KEY not set in .env');
  throw new Error('GEMINI_API_KEY is missing');
}

const ai = new GoogleGenAI({ apiKey });
const MODEL = process.env.GEMINI_MODEL || 'gemini-2.0-flash';

/**
 * Internal helper: call Gemini and return plain text.
 * IMPORTANT: never throw here – always return a string (possibly empty)
 * so callers can handle fallback cleanly.
 */
async function generateText(prompt) {
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

    const text = (response.text || '').trim();
    if (!text) {
      console.warn('[translate.gemini] Empty response from Gemini');
    }
    return text;
  } catch (err) {
    if (err instanceof ApiError) {
      console.error(
        '[translate.gemini] ApiError:',
        err.status,
        JSON.stringify(err.response, null, 2)
      );
    } else {
      console.error('[translate.gemini] Error:', err?.message || err);
    }
    // Do NOT rethrow – return empty so upper layers can fall back safely
    return '';
  }
}

/* ============================
   FOOD NAME TRANSLATOR (STRICT)
   ============================ */
export async function translateFoodName(text) {
  if (!text || !text.trim()) return text;

  const prompt = `
Translate the following FOOD NAME into Bangla.

STRICT RULES:
- Only return the Bangla translation.
- No explanations.
- No English words.
- No parentheses.
- No bullet points.
- No extra sentences.
- Preserve commas if present.
- Output MUST be a single clean line.

TEXT: "${text}"
  `.trim();

  try {
    let out = await generateText(prompt);
    if (!out) out = text;

    // Remove accidental newlines or formatting
    out = out.replace(/\n+/g, ' ').trim();

    return out;
  } catch (err) {
    console.error('[translateFoodName] Fallback due to error:', err?.message);
    // fallback: do NOT break API
    return text;
  }
}

/* ============================
   EDUCATION TRANSLATOR
   ============================ */
export async function translateToBn(text) {
  if (!text || !text.trim()) return '';

  const prompt = `
You are a professional medical translator.

TASK:
Translate the following patient-education text into Bangla (Bangladesh).

OUTPUT RULES (VERY IMPORTANT):
- Output ONLY the final Bangla translation.
- Do NOT include any English text.
- Do NOT include explanations, notes, alternatives, or commentary.
- Do NOT include pronunciation, transliteration, bullet lists, or headings.
- Do NOT write "Here is the translation" or similar phrases.
- Do NOT repeat the original English text.
- Keep paragraphs and line breaks similar to the original where helpful.

TEXT TO TRANSLATE:
${text}
  `.trim();

  try {
    let out = await generateText(prompt);
    if (!out) {
      console.warn('[translateToBn] Empty output, falling back to English');
      return text;
    }
    return out;
  } catch (err) {
    console.error('[translateToBn] Fallback due to error:', err?.message);
    // Fallback so API does not break – show English instead of crashing
    return text;
  }
}

/* ============================
   FIELD-WISE TRANSLATION
   ============================ */
export async function translateFieldsToBn(obj, fields) {
  const out = { ...obj };
  for (const f of fields) {
    const v = obj[f] ?? '';
    out[`${f}_bn`] = await translateToBn(String(v));
  }
  return out;
}

/* ============================
   GENERAL EDUCATION TEXT SWITCHER
   ============================ */
export async function translateEduText(text, targetLang = 'bn') {
  if (!text?.trim()) return '';
  if (targetLang !== 'bn') return text;
  return translateToBn(text);
}
