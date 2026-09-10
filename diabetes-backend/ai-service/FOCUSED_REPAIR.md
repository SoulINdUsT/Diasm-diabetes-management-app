**DIAsm chatbot repair: final handoff (2026-09-10)**

**READY FOR ANDROID TESTING** for controlled developer QA against the current local Node/FastAPI services. This is not approval for clinical use or a production release. Nothing was deployed. No chat-history persistence or other chatbot feature was added.

The final audit covered the current tracked diff, untracked chatbot modules and tests, routing/copy/engine/evidence adapters, all three saved review artifacts, and the Node service/controller/routes. The actual review filenames are `manual_review_offline.json`, `manual_review_live.json`, and `manual_review_benchmark_live.json`; there is no separate `manual_review_live_live.json`.

**What the previous sessions accomplished**

- Replaced inconsistent diagnostic scripts and the monolithic answer path with shared production routing, evidence selection, generation validation and FastAPI adapters. `query_test.py` and the evaluator now use that same path.
- Added deterministic emergency, hypoglycaemia, pregnancy and insulin-dose boundaries before ordinary retrieval/generation, including consciousness/swallowing safeguards and bounded negation/educational handling.
- Corrected management, breakfast, foods-to-limit, HbA1c and care-seeking behavior. HbA1c uses the exact grammatical definition supported by `type2_en_019`; a personal target or ambiguous limit still asks for clarification. Broad doctor questions distinguish routine follow-up from a current urgent symptom and retain red flags.
- Kept generation failure/rejection reasons out of user answers, retained usable evidence answers, and added exception-type and elapsed-time diagnostics. The original historical first-call generation-unavailable cause was not established; no timeout was increased to conceal it.
- Corrected an incomplete benchmark gold label: both `complications_en_101` and `complications_en_414` directly answer the general uncontrolled-diabetes organ-damage question. Retrieval was correct; the label fix did not require new knowledge or embeddings.
- Corrected all nine documented manual-review defects using existing source passages/Q&A and existing safety policy copy. Protected passages must survive generation intact; otherwise the complete prepared evidence is returned.
- Added regression, safety, contract and evidence-equivalence tests and retained all benchmark answers for review.

All of that work is still uncommitted. The user?s separate authentication, Flutter, package-script and other changes also remain uncommitted and were preserved, without extending their scope.

**What was incomplete and finished in this final session**

1. Node dropped `evidence_sources`, `generation_error_type`, and `generation_elapsed_ms`. It now forwards them as structured metadata, preserving the user answer unchanged.
2. A successful HTTP response with a missing, blank or non-string answer could reach Android as an empty bubble. Node now rejects that payload and returns a clean nonempty outage response. HTTP errors, malformed JSON and connection failures use the same path.
3. The old Node outage message told users to try again later, even when seriously unwell, and labeled English text as Bangla for a Bangla request. It now reuses the existing serious-illness urgent-help sentence, reports the actual English language, retains the requested language and flags unavailable translation and clinical review. No new medical instruction was invented.
4. Node logged whole exception objects. Logs now retain only the exception type, without raw upstream/request content. Configured AI URLs with a trailing slash are also handled correctly.
5. The handoff note and offline artifact described superseded behavior and results. They are now current. Focused review output now saves all 30 answers, including the 18 safety cases, and both live artifacts record per-request elapsed time.

The private legacy prompt/paragraph helpers in the Node module remain unused by `getAnswer`. They were not removed as part of a redesign. Tests confirm that they do not truncate the live answer or its safety qualifications. Python medical routing, copy, source-preparation and generation rules were not changed in this final session.

**Before/after behavior of the nine medical-answer repairs**

These repairs were already implemented when the final session began; every one was reverified in the final live benchmark. Full original and final answer text is retained under `manual_review_findings.findings` in the benchmark JSON.

| Question | Original defect | Current behavior / repair layer |
| --- | --- | --- |
| Can diabetes be cured? | Remission answer omitted continuing care. | Generation preserves non-permanent-cure and regular-monitoring qualifications from `basics_en_027`. |
| What if sugar drops during workout? | Omitted when exercise may resume and the existing swallowing/consciousness boundary. | Prompt supplies existing low-glucose policy copy; generation preserves it completely, with policy-copy provenance distinguished from KB text. |
| Why am I always hungry? | Gave management tips without explaining hunger. | Prompt includes the existing `nutrition_en_307` explanatory Q&A first, retaining its ?may? qualification. |
| I feel depressed | Omitted professional and emergency escalation. | Generation preserves both supplied escalation sentences in `mental_en_006`. |
| I am always thirsty and urinate a lot, should I get tested? | Presumed a diagnosis and lacked assessment/testing evidence. | Selection adds `type2_en_003` and the threshold-free testing Q&A from `type2_en_006`; generation retains general assessment language. |
| What happens if diabetes is not treated for years? | ?Diabetes complications damages the body.? | Generation retains grammatical `complications_en_002` source prose and its emergency qualification. |
| Why is protein in urine dangerous for diabetic patients? | Supporting Q&A was absent from the model?s evidence. | Prompt includes the kidney-signs Q&A from `type2_en_032`, preserving context and qualifications. |
| Why are foot wounds risky in diabetes? | Wounds were incorrectly described as causing unnoticed injuries. | Generation preserves poor circulation/slow healing and reduced sensation/missed injuries in the foot sources. |
| What precautions should I take before exercise? | A source interval became a personal glucose target. | Prompt retains existing nonnumeric checking/avoidance guidance; no replacement interval or personal target is introduced. |

The original focused repairs are also stable: the A1C definition is ?The A1C test measures your average blood sugar level over the past two to three months.? Broad care-seeking asks about routine follow-up versus an urgent current symptom. The HbA1c-target clarification does not assign a threshold. Low-glucose and emergency responses retain their deterministic safeguards.

**Exact files changed in this final session**

Relative to `D:/DIAsm/`:

- `diabetes-backend/ai-service/evaluate.py`
- `diabetes-backend/ai-service/test_complication_evidence.py`
- `diabetes-backend/ai-service/FOCUSED_REPAIR.md`
- `diabetes-backend/ai-service/manual_review_offline.json`
- `diabetes-backend/ai-service/manual_review_live.json`
- `diabetes-backend/ai-service/manual_review_benchmark_live.json`
- `diabetes-backend/src/modules/chatbot/chatbot.service.js`
- `diabetes-backend/test/chatbot.rag.test.js`

**Complete uncommitted chatbot-file inventory across the prior and final sessions**

Tracked files modified relative to HEAD:

- `diabetes-backend/ai-service/main.py`
- `diabetes-backend/ai-service/evaluate.py`
- `diabetes-backend/ai-service/evaluation_questions.json`
- `diabetes-backend/ai-service/query_test.py`
- `diabetes-backend/src/modules/chatbot/chatbot.service.js`

New, untracked files:

- `diabetes-backend/ai-service/assistant_policy.py`
- `diabetes-backend/ai-service/assistant_engine.py`
- `diabetes-backend/ai-service/assistant_evidence.py`
- `diabetes-backend/ai-service/assistant_copy.py`
- `diabetes-backend/ai-service/regression_cases.json`
- `diabetes-backend/ai-service/safety_cases.json`
- `diabetes-backend/ai-service/test_regression.py`
- `diabetes-backend/ai-service/test_contract.py`
- `diabetes-backend/ai-service/test_complication_evidence.py`
- `diabetes-backend/ai-service/test_review_repairs.py`
- `diabetes-backend/ai-service/manual_review_offline.json`
- `diabetes-backend/ai-service/manual_review_live.json`
- `diabetes-backend/ai-service/manual_review_benchmark_live.json`
- `diabetes-backend/ai-service/FOCUSED_REPAIR.md`
- `diabetes-backend/test/chatbot.rag.test.js`

**Final verification**

| Check | Result |
| --- | --- |
| Python unit/regression/FastAPI contract suite | 39 passed |
| Node chatbot suite | 5 passed; includes forwarding all 68 saved payloads through the controller, metadata, long safety text, invalid inputs and upstream failures |
| Current Node service to local FastAPI deterministic emergency smoke | Passed; no retrieval or generation |
| Offline focused evaluation | 30/30; safety 18/18; evidence 6/6 |
| Offline benchmark evaluation | 68/68; safety 18/18; evidence 48/48 |
| Final live focused evaluation, run once | 30/30; safety 18/18; evidence 6/6 |
| Final live benchmark evaluation, run once | 68/68; safety 18/18; evidence 48/48 |
| Final source-preservation review | All nine repaired answers exactly match their complete prepared evidence |
| Internal answer-text checks | No internal generation/fallback terminology in any of the 98 saved live answers |
| Python/Node syntax and scoped diff whitespace checks | Passed |

Focused live modes: 3 generated, 3 evidence fallbacks, 4 clarifications and 20 safety responses. Benchmark live modes: 44 generated, 4 evidence fallbacks, 1 clarification and 19 safety responses. Structural success does not award clinical correctness.

The final live focused maximum was 7,291 ms; the benchmark maximum was 5,406 ms. None of these sampled FastAPI requests exceeded the existing Android 10-second receive timeout. The median benchmark request was 3,233 ms. These are local, sequential measurements; they exclude Android network/Node overhead and do not establish cold-start or concurrent-load performance. FastAPI?s retrieval dependencies were already initialized. No service restart was needed because this session did not change Python serving code.

The final benchmark differs from the prior reviewed answers in only three ordinary cases: tingling/neuropathy has equivalent wording, the kidney answer now names nephropathy explicitly using supplied text, and the post-meal walking answer remains a terse yes. No new serious unsupported, unrelated-topic, insulin-dose or emergency-advice problem was found in that comparison.

**Remaining limitations and clinical review**

- All deterministic safety copy and Bangla translations still require clinical review. All nine repaired responses carry `clinical_review_required=true`; this identifies review work, not clinical validation.
- Existing proteinuria wording, exercise guidance, remission qualifications and the reused transport-outage urgent-help sentence need clinical review before clinical reliance. Source text was not medically rewritten.
- English-only protected passages cannot be freely translated without weakening preservation. A Bangla request may receive English with `requested_language=bn` and `translation_unavailable=true`. Existing deterministic Bangla safety copy is unchanged. The current Flutter screen displays answer text but does not surface these metadata flags; Flutter was not edited.
- Exact source preservation can produce long or repetitive answers. Ordinary generated answers outside the protected passages still use structural/topic checks, not a complete factual-entailment validator. Some answers remain terse.
- Emergency matching and negation are deliberately bounded. The tests do not establish coverage for every phrasing, language or clinical scenario.
- If the entire FastAPI service is down, Node cannot supply its detailed deterministic safety responses; it supplies a clean outage response with an existing general urgent-help boundary. This differs from Ollama being down, where FastAPI can still supply full evidence/safety answers.
- The first historical generation-unavailable event remains unattributed because its original exception details were not retained. Current typed diagnostics do not prove that old event?s cause. Ollama remains `llama3.1:8b`, with the existing 2-second connect/6-second read timeout and no paid API.

**Chroma and Android-testing recommendation**

No Chroma rebuild is required. No ingestion, add/upsert/delete, knowledge edit or embedding rebuild was performed. All 141 baseline Chroma file hashes are unchanged in this final session. Earlier runtime storage-file changes remain documented separately in the benchmark artifact; they are not changes from this session. Knowledge, model selection, `.env`, authentication, Flutter, MySQL and unrelated work were preserved.

Proceed with controlled Android testing using the existing `API_BASE_URL` build option pointed at the current reachable Node backend. The app?s existing default remote URL has not received these uncommitted local repairs, because nothing was deployed. Verify device connectivity, language fallback display, long answers, emergency responses and real-device latency. The current evidence supports developer QA readiness; clinical review and the listed limits prevent treating these test results as release or medical-use approval.
