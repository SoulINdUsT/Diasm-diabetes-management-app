// src/modules/lifestyle/lifestyle.service.js
import { translateToBn } from '../../services/translate.gemini.js';

export function round2(x) {
  return Math.round((Number(x) + Number.EPSILON) * 100) / 100;
}

// Translate selected fields of an object if lang requested.
// Pass array of field names that should be translated.
export async function maybeTranslate(obj, lang, fields = []) {
  if (!lang || lang === 'en') return obj;
  const copy = { ...obj };
  await Promise.all(fields.map(async f => {
    if (copy[f]) copy[f] = await translateToBn(String(copy[f]), lang);
  }));
  return copy;
}
