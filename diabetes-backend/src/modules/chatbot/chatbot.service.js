
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROMPTS_DIR = path.join(__dirname, 'prompts');

// ---------- utils
const isBangla = (s) => /[\u0980-\u09FF]/.test(s || '');

function safeReadFile(fullPath) {
  try {
    return fs.readFileSync(fullPath, 'utf-8');
  } catch {
    return '';
  }
}

// CRLF-safe section parsing; works even if no headings exist
function parseSections(raw, fileName) {
  if (!raw) return [];
  const text = raw.replace(/\r\n/g, '\n');

  // Split when a new "## " heading starts (keep heading in block)
  const blocks = text.split(/\n(?=##\s)/g);

  if (blocks.length === 1 && !/^##\s/.test(text)) {
    return [{ file: fileName, title: 'General', content: text.trim() }];
  }

  return blocks.map((b) => {
    const m = b.match(/^##\s*(.+?)\s*$/m);
    const title = m ? m[1].trim() : 'Section';
    return { file: fileName, title, content: b.trim() };
  });
}

// Clean markdown and return first readable paragraph
function firstParagraph(text, maxChars = 900, lang = null) {
  if (!text) return '';

  let cleaned = String(text).replace(/\r\n/g, '\n');

  //
  // 1) If this block is bilingual (EN/BN), focus on the requested language part
  //
  if (lang === 'bn') {
    // Look for a BN marker line like "**BN:**" or "BN:"
    const m = cleaned.match(/(^|\n)\s*(\*\*BN\s*:\*\*|BN\s*:)\s*/i);
    if (m && typeof m.index === 'number') {
      cleaned = cleaned.slice(m.index + m[0].length);
    }
  } else if (lang === 'en') {
    // Look for an EN marker line like "**EN:**" or "EN:"
    const m = cleaned.match(/(^|\n)\s*(\*\*EN\s*:\*\*|EN\s*:)\s*/i);
    if (m && typeof m.index === 'number') {
      cleaned = cleaned.slice(m.index + m[0].length);
    }
  }

  //
  // 2) Existing cleaning logic
  //

  // Remove emoji/SECTION lines like "🧠 SECTION 1: DIABETES BASICS"
  cleaned = cleaned.replace(
    /^[^\n]*SECTION\s*\d*\s*:[^\n]*\n+/im,
    ''
  );

  // Remove leading "(File: xxx.txt)" line if present
  cleaned = cleaned.replace(/^\s*\(File:[^)]+\)\s*\n+/im, '');

  // Remove leading markdown headings (H1–H6) and underline-style titles
  cleaned = cleaned
    .replace(/^(\s*#{1,6}\s.*\n+)+/m, '')   // leading #, ##, ### ... headings
    .replace(/^[^\n]*\n[=-]{3,}\n+/m, '');  // underline (=== / ---) headings

  // Strip common markdown formatting
  cleaned = cleaned
    .replace(/\*\*(.*?)\*\*/g, '$1')        // bold
    .replace(/__(.*?)__/g, '$1')            // underline
    .replace(/_([^_]+)_/g, '$1')            // italics
    .replace(/`{1,3}([^`]+)`{1,3}/g, '$1')  // backticks
    .replace(/\n{3,}/g, '\n\n');            // collapse extra blank lines

  // Drop pure decoration lines like "#####====" or "#==========="
  cleaned = cleaned.replace(/^[#=\-\s]+$/gm, '');

  cleaned = cleaned.trim();
  if (!cleaned) return '';

  const paras = cleaned
    .split(/\n\s*\n/)
    .map((p) => p.trim())
    .filter(Boolean);

  let out = paras[0] || cleaned;

  //
  // 3) Special rules to skip title-only first paragraph
  //    - Case 1: short question (e.g., "What is Diabetes?")
  //    - Case 2: short heading without sentence punctuation
  //
  if (paras.length > 1) {
    const isShortQuestion = out.endsWith('?') && out.length <= 140;
    const isShortHeading =
      out.length <= 80 && !/[.।!?]/.test(out); // no sentence punctuation

    if (isShortQuestion || isShortHeading) {
      out = paras[1];
    }
  }

  //
  // 4) Drop leading labels like "Description:", "EN:", "BN:" once
  //
  out = out.replace(/^\s*(Description|EN|BN)\s*:\s*/i, '');

  if (out.length > maxChars) out = out.slice(0, maxChars) + '…';

  // Flatten remaining newlines -> spaces (so no "\n" in JSON)
  out = out.replace(/\s*\n+\s*/g, ' ').replace(/\s{2,}/g, ' ').trim();
  return out;
}


// tiny token overlap score
function score(query, hay) {
  const q = (query || '').toLowerCase();
  const h = (hay || '').toLowerCase();
  const tokens = q.split(/[^\p{L}\p{N}]+/u).filter(Boolean);
  let s = 0;
  for (const t of tokens) if (h.includes(t)) s += 1;
  return s;
}

// Keyword hints to route common intents fast
// Keyword hints to route common intents fast
const KEYWORDS_MAP = {
  bn: [
    {
      kw: ['লো সুগার', 'হাইপো', 'চিনি কমে গেলে'],
      hint: 'low sugar',
      preferFiles: ['glucose', 'insulin'],
    },
    {
      kw: ['হাই সুগার', 'হাইপার', 'চিনি বেড়ে গেলে'],
      hint: 'high sugar',
      preferFiles: ['glucose', 'insulin'],
    },
    { kw: ['ইনসুলিন', 'ডোজ'], hint: 'insulin', preferFiles: ['glucose', 'insulin'] },
    { kw: ['পায়ের যত্ন', 'ফুট কেয়ার'], hint: 'foot care', preferFiles: ['complication'] },
    {
      kw: ['চোখ', 'রেটিনা', 'দৃষ্টি'],
      hint: 'চোখের সমস্যা',
      preferFiles: ['complication_bn', 'complication'],
    },
    { kw: ['কিডনি', 'প্রস্রাব', 'অ্যালবুমিন'], hint: 'kidney', preferFiles: ['complication'] },

    // 🔹 Diet: healthy foods for diabetes (general “what should I eat” in BN)
    {
      kw: [
        'কী ধরনের খাবারগুলো',
        'কি ধরনের খাবারগুলো',
        'কী ধরনের খাবার',
        'কি ধরনের খাবার',
        'কী কী ধরনের খাবার',
        'কি কি ধরনের খাবার',
        'ডায়াবেটিসে কী খাবো',
        'ডায়াবেটিসে কি খাবো'
      ],
      hint: 'ডায়াবেটিসে সুস্থ খাবার',
      preferFiles: ['food_diabetes'],
    },

    // 🔹 Diet: healthy foods for diabetes
    {
      kw: ['কোন খাবার ভালো', 'সুস্থ খাবার', 'ডায়াবেটিসে কী খাওয়া ভালো'],
      hint: 'healthy foods for diabetes',
      preferFiles: ['food_diabetes'],
    },
    // 🔹 Diet: foods to limit / avoid
    {
      kw: ['কোন খাবারগুলো কম খাওয়া', 'খাবারগুলো কম খাওয়া', 'এড়িয়ে চলা উচিত'],
      hint: 'foods to limit or avoid',
      preferFiles: ['food_diabetes'],
    },

    // 🔹 Pulses / dal questions (মুগ ডাল, মসুর ডাল, ছোলা)
    {
      kw: ['ডাল', 'মুগ ডাল', 'মসুর ডাল', 'ছোলা'],
      hint: 'ডাল ও প্রোটিন',
      preferFiles: ['food_diabetes'],
    },

    { kw: ['ধ্যান', 'শ্বাস', 'ঘুমের আগে ধ্যান'], hint: 'meditation' },
    { kw: ['স্ট্রেস', 'মন খারাপ', 'হতাশা'], hint: 'emotional' },
    {
      kw: ['ব্যায়াম', 'হাঁটা', 'হাটতে'],
      hint: 'exercise for diabetes',
      preferFiles: ['diabetes_excercise', 'exercise_tips_bn'],
    },
  ],
  en: [
    {
      kw: ['hypo', 'low sugar'],
      hint: 'low sugar',
      preferFiles: ['glucose', 'insulin'],
    },
    {
      kw: ['hyper', 'high sugar'],
      hint: 'high sugar',
      preferFiles: ['glucose', 'insulin'],
    },
    { kw: ['insulin', 'dose'], hint: 'insulin', preferFiles: ['glucose', 'insulin'] },
    { kw: ['foot', 'ulcer'], hint: 'foot care', preferFiles: ['complication'] },
    { kw: ['retina', 'eyes', 'vision'], hint: 'retina', preferFiles: ['complication'] },
    { kw: ['kidney', 'albumin', 'urine'], hint: 'kidney', preferFiles: ['complication'] },

    // 🔹 Diet: healthy diet & foods
    {
      kw: ['healthy diet for diabetes', 'diabetes diet', 'healthy diet'],
      hint: 'healthy diet for diabetes',
      preferFiles: ['food_diabetes'],
    },
    {
      kw: ['what foods are good for diabetes', 'foods are good for diabetes', 'healthy foods for diabetes'],
      hint: 'foods are good for diabetes',
      preferFiles: ['food_diabetes'],
    },
    // 🔹 Diet: foods to limit / avoid
    {
      kw: ['foods should i limit', 'foods should i avoid', 'limit or avoid if i have diabetes'],
      hint: 'foods to limit or avoid in diabetes',
      preferFiles: ['food_diabetes'],
    },

    // 🔹 Soft drinks / sugary drinks
    {
      kw: [
        'soft drink',
        'soft drinks',
        'cold drink',
        'cold drinks',
        'soda',
        'sugary drink',
        'sugary drinks'
      ],
      hint: 'sugary drinks and soft drinks to avoid in diabetes',
      preferFiles: ['food_diabetes'],
    },

    { kw: ['meditation', 'breathing', 'sleep'], hint: 'meditation' },
    { kw: ['stress', 'burnout', 'depression'], hint: 'emotional' },
    {
      kw: ['exercise', 'walking', 'walk'],
      hint: 'exercise for diabetes',
      preferFiles: ['diabetes_excercise'],
    },
    {
      kw: ['metformin', 'tablet', 'medicine'],
      hint: 'metformin',
      preferFiles: ['medication_awareness'],
    },
  ],
};


function applyKeywordHint(message, lang, pool) {
  const map = KEYWORDS_MAP[lang] || [];
  const msgLower = (message || '').toLowerCase();

  for (const entry of map) {
    if (entry.kw.some((k) => msgLower.includes(k.toLowerCase()))) {
      let best = null;
      let bestScore = -1;

      for (const s of pool) {
        let sc = score(entry.hint, s.title) + score(entry.hint, s.content);

        // extra bonus if file name matches preferred files
        if (entry.preferFiles && entry.preferFiles.length) {
          const file = (s.file || '').toLowerCase();
          if (entry.preferFiles.some((p) => file.includes(p.toLowerCase()))) {
            sc += 5;
          }
        }

        if (sc > bestScore) {
          best = s;
          bestScore = sc;
        }
      }

      if (best) {
        return {
          answer: firstParagraph(best.content, 900, lang),
          source: { type: 'section', file: best.file, section: best.title, lang },
        };
      }
    }
  }
  return null;
}

// ---------- in-memory index
let INDEX = {
  bn: [], // {file,title,content}
  en: [], // {file,title,content}
  foods: [], // {name_en,name_bn,category,kcal,advice_bn,file}
};

function loadFoods() {
  let files = [];
  try {
    files = fs.readdirSync(PROMPTS_DIR).filter((f) => /^food/i.test(f));
  } catch {
    files = [];
  }
  const rows = [];
  for (const f of files) {
    const text = safeReadFile(path.join(PROMPTS_DIR, f));
    if (!text) continue;
    text.split('\n').forEach((line) => {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) return;
      const parts = trimmed.split('|').map((x) => x.trim());
      if (parts.length < 5) return;
      const [name_en, name_bn, category, kcal, advice_bn] = parts;
      rows.push({ name_en, name_bn, category, kcal, advice_bn, file: f });
    });
  }
  INDEX.foods = rows;
}

function loadKnowledge() {
  let files = [];
  try {
    files = fs
      .readdirSync(PROMPTS_DIR)
      .filter((f) => fs.statSync(path.join(PROMPTS_DIR, f)).isFile());
  } catch {
    files = [];
  }

  const bn = [];
  const en = [];

  for (const f of files) {
    const text = safeReadFile(path.join(PROMPTS_DIR, f));
    if (!text) continue;

    const sections = parseSections(text, f);

    // Detect language presence
    const hasBn = /[\u0980-\u09FF]/.test(text);
    const hasEn = /[A-Za-z]/.test(text);

    if (hasBn && !hasEn) {
      bn.push(...sections);
    } else if (!hasBn && hasEn) {
      en.push(...sections);
    } else if (hasBn && hasEn) {
      // Bilingual file: use for both languages
      bn.push(...sections);
      en.push(...sections);
    } else {
      // Fallback: if somehow neither detected, treat as English
      en.push(...sections);
    }
  }

  INDEX.bn = bn;
  INDEX.en = en;
}

// Load on import
loadKnowledge();
loadFoods();

// Hot reload in dev (safe no-op in prod hosts)
try {
  fs.watch(PROMPTS_DIR, { persistent: false }, () => {
    setTimeout(() => {
      loadKnowledge();
      loadFoods();
    }, 120);
  });
} catch {
  /* ignore */
}


// Match a full word (Bangla or English), not just substring like "আম" inside "আমার"
function matchWord(message, term) {
  if (!message || !term) return false;

  const msg = message.toLowerCase();
  const t = term.toLowerCase().trim();
  if (!t) return false;

  // escape regex specials
  const escaped = t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

  // include Bangla danda "।" as boundary as well
  const pattern = new RegExp(`(^|[\\s,.;!?।])${escaped}($|[\\s,.;!?।])`, 'i');
  return pattern.test(msg);
}


/// -------- food search
function findFoodAnswer(message) {
  const byBn = INDEX.foods.find((f) =>
    matchWord(message, f.name_bn || '')
  );
  const byEn = INDEX.foods.find((f) =>
    matchWord(message, f.name_en || '')
  );
  const item = byBn || byEn;
  if (!item) return null;

  const lines = [
    `${item.name_bn || item.name_en} (${item.category})`,
    `Per 100g ≈ ${item.kcal} kcal.`,
    item.advice_bn || '',
  ].filter(Boolean);

  const answer = firstParagraph(lines.join(' ')); // flatten anyway

  return {
    answer,
    source: { type: 'food', file: item.file, key: item.name_en },
  };
}


function findKnowledgeAnswer(message, langPref) {
  const lang = langPref || (isBangla(message) ? 'bn' : 'en');
  const pool = lang === 'bn' ? INDEX.bn : INDEX.en;

  const q = (message || '').toLowerCase().trim();

  // Special BN case: eye complications ("ডায়াবেটিসের চোখের কী কী সমস্যা হতে পারে" etc.)
  if (lang === 'bn' && /চোখ/.test(q)) {
    const eyesBn = pool.find(
      (s) =>
        /complication_bn/i.test(s.file || '') &&
        (/চোখ/.test(s.title || '') || /চোখ/.test(s.content || ''))
    );

    if (eyesBn) {
      return {
        answer: firstParagraph(eyesBn.content, 900, lang),
        source: {
          type: 'section',
          file: eyesBn.file,
          section: eyesBn.title,
          lang,
        },
      };
    }
  }

  // Special BN case: general "what should I eat" diet question
  // e.g. "ডায়াবেটিস থাকলে প্রতিদিনের জন্য কী ধরনের খাবারগুলো বেশি রাখা ভালো?"
  if (lang === 'bn' && /ডায়াবেটিস/.test(q) && /খাবার/.test(q)) {
    const dietBn = pool.find(
      (s) =>
        /food_diabetes/i.test(s.file || '') &&
        /what is a healthy diet for diabetes\?/i.test(
          (s.title || '').toLowerCase()
        )
    );

    if (dietBn) {
      return {
        answer: firstParagraph(dietBn.content, 900, lang),
        source: {
          type: 'section',
          file: dietBn.file,
          section: dietBn.title,
          lang,
        },
      };
    }
  }

  // Special intro question: "what is diabetes"
  if (lang === 'en' && q.includes('what is diabetes')) {
    const basics = pool.find((s) => /diabetes_basics/i.test(s.file || ''));
    if (basics) {
      return {
        answer: firstParagraph(basics.content, 900, lang),
        source: { type: 'section', file: basics.file, section: basics.title, lang },
      };
    }
  }

  // Try keyword hints first
  const hinted = applyKeywordHint(message, lang, pool);
  if (hinted) return hinted;

  // Then exact title containment
  const exact = pool.find((s) => q.includes((s.title || '').toLowerCase()));
  if (exact) {
    return {
      answer: firstParagraph(exact.content, 900, lang),
      source: { type: 'section', file: exact.file, section: exact.title, lang },
    };
  }

  // Otherwise, best score across title + content
  let best = null;
  let bestScore = -1;
  for (const s of pool) {
    const sc = score(message, s.title) + score(message, s.content);
    if (sc > bestScore) {
      best = s;
      bestScore = sc;
    }
  }

  if (!best) {
    if (lang === 'bn') {
      return {
        answer: firstParagraph(
          'এই প্রশ্নটি একটু নির্দিষ্ট করে বলুন—যেমন: "ইনসুলিন কিভাবে নেব?", "লো সুগারে কী করবো?"',
        ),
        source: null,
      };
    }
    return {
      answer: firstParagraph(
        'Please be a bit more specific—e.g., "How to take insulin?", "What to do in low sugar?"',
      ),
      source: null,
    };
  }

  return {
    answer: firstParagraph(best.content, 900, lang),
    source: { type: 'section', file: best.file, section: best.title, lang },
  };
}

// -------- public API
export async function getAnswer(message, lang = 'en') {
  try {
    const response = await fetch('http://127.0.0.1:8000/ask', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        question: message,
        language: lang || 'en',
      }),
    });

    if (!response.ok) {
      throw new Error(`AI service error: ${response.status}`);
    }

    const data = await response.json();

    return {
      answer: data.answer,
      category: data.category,
      categories: data.categories,
      language: data.language,
      intent: data.intent,
      retrieved_ids: data.retrieved_ids,
    };
  } catch (error) {
    console.error('[chatbot.service] AI service error:', error);

    return {
      answer: 'Sorry, the AI assistant is temporarily unavailable. Please try again later.',
      category: 'error',
      categories: [],
      language: lang || 'en',
      intent: 'fallback',
      retrieved_ids: [],
    };
  }
}