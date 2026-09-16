import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { ask } from '../src/modules/chatbot/chatbot.controller.js';
import { getAnswer } from '../src/modules/chatbot/chatbot.service.js';

test('chatbot preserves configured AI URL and forwards provenance without invented retrieval', async () => {
  const originalFetch = globalThis.fetch;
  const oldUrl = process.env.AI_SERVICE_URL;
  const payload = {
    answer: 'Safety response', intent: 'emergency_swallowing', language: 'bn',
    requested_language: 'bn', knowledge_language: 'en', category: null, categories: [],
    evidence_ids: [], retrieved_ids: [], response_mode: 'safety', retrieval_performed: false,
    clinical_review_required: true, safety_copy_version: 'focused-repair-v1-unreviewed',
    evidence_sources: { exercise_en_008: { fields: ['assistant_copy.COPY.low_glucose_actions.en'], origin: 'retrieved_record' } },
    generation_error_type: 'ReadTimeout', generation_elapsed_ms: 6012,
  };
  try {
    process.env.AI_SERVICE_URL = 'http://ai-contract.invalid';
    globalThis.fetch = async (url, options) => {
      assert.equal(url, 'http://ai-contract.invalid/ask');
      assert.deepEqual(JSON.parse(options.body), { question: 'cannot swallow', language: 'bn' });
      return { ok: true, json: async () => payload };
    };
    const result = await getAnswer('cannot swallow', 'bn');
    for (const [key, value] of Object.entries(payload)) assert.deepEqual(result[key], value);
  } finally {
    globalThis.fetch = originalFetch;
    if (oldUrl === undefined) delete process.env.AI_SERVICE_URL;
    else process.env.AI_SERVICE_URL = oldUrl;
  }
});

test('all saved benchmark answers and metadata reach the Node controller unchanged', async () => {
  const rows = JSON.parse(readFileSync(new URL('../ai-service/manual_review_benchmark_live.json', import.meta.url), 'utf8')).manual_review;
  assert.equal(rows.length, 68);
  const originalFetch = globalThis.fetch;
  try {
    for (const row of rows) {
      const upstream = row.result;
      globalThis.fetch = async (_url, options) => {
        assert.equal(JSON.parse(options.body).question, row.question);
        return { ok: true, json: async () => upstream };
      };
      let delivered;
      await ask({ body: { message: ` ${row.question} `, lang: upstream.requested_language } }, {
        json(value) { delivered = value; },
        status() { assert.fail('valid question should not fail'); },
      });
      for (const [key, value] of Object.entries(upstream)) {
        assert.deepEqual(delivered[key], value, `${row.question}: ${key}`);
      }
    }
  } finally { globalThis.fetch = originalFetch; }
});

test('long safety qualifications are never truncated by legacy paragraph helpers', async () => {
  const originalFetch = globalThis.fetch;
  const answer = 'Source context. '.repeat(100) + 'If there is any risk of harming yourself or others, seek emergency help immediately.';
  try {
    globalThis.fetch = async () => ({ ok: true, json: async () => ({ answer }) });
    assert.equal((await getAnswer('I feel depressed')).answer, answer);
  } finally { globalThis.fetch = originalFetch; }
});

test('missing, malformed and failed upstream answers give a clean, correctly labeled response', async () => {
  const originalFetch = globalThis.fetch;
  const originalError = console.error;
  const logs = [];
  try {
    console.error = (...args) => logs.push(args);
    const responses = [null, {}, { answer: '' }, { answer: '  ' }, { answer: 7 }];
    const fetches = responses.map(data => async () => ({ ok: true, json: async () => data }));
    fetches.push(async () => ({ ok: false, status: 503 }));
    fetches.push(async () => ({ ok: true, json: async () => { throw new SyntaxError('PRIVATE upstream content'); } }));
    fetches.push(async () => { throw new TypeError('PRIVATE request details'); });
    for (const fetch of fetches) {
      globalThis.fetch = fetch;
      const result = await getAnswer('I feel seriously unwell', 'bn');
      assert.equal(result.response_mode, 'unavailable');
      assert.equal(result.language, 'en');
      assert.equal(result.requested_language, 'bn');
      assert.equal(result.translation_unavailable, true);
      assert.equal(result.retrieval_performed, false);
      assert.deepEqual(result.evidence_ids, []);
      assert.match(result.answer, /If you feel seriously unwell, seek urgent medical help/);
      assert.doesNotMatch(result.answer, /PRIVATE|generation_|fallback|try again later/);
      assert.equal(result.clinical_review_required, true);
    }
    assert.doesNotMatch(JSON.stringify(logs), /PRIVATE/);
  } finally {
    globalThis.fetch = originalFetch;
    console.error = originalError;
  }
});

test('configured trailing slash is accepted and invalid controller messages never call AI', async () => {
  const originalFetch = globalThis.fetch;
  const oldUrl = process.env.AI_SERVICE_URL;
  let calls = 0;
  try {
    process.env.AI_SERVICE_URL = 'http://ai-contract.invalid/';
    globalThis.fetch = async (url) => {
      calls += 1;
      assert.equal(url, 'http://ai-contract.invalid/ask');
      return { ok: true, json: async () => ({ answer: 'Source answer.' }) };
    };
    await getAnswer('question');
    for (const message of ['', ' ', 42, null]) {
      let status;
      let body;
      await ask({ body: { message } }, {
        status(value) { status = value; return this; },
        json(value) { body = value; },
      });
      assert.equal(status, 400);
      assert.deepEqual(body, { error: 'message is required' });
    }
    assert.equal(calls, 1);
  } finally {
    globalThis.fetch = originalFetch;
    if (oldUrl === undefined) delete process.env.AI_SERVICE_URL;
    else process.env.AI_SERVICE_URL = oldUrl;
  }
});
