# Bangla regression repair — 2026-09-10

The worktree was clean at checkpoint `89ed94f` when this repair started. Previous repairs are committed there; this repair is uncommitted.

## Confirmed cause and history

- Parent `aeb52fc` had English intent rules, removed Bangla combining marks, and defaulted unmatched questions to `basics_info`. Running its extracted policy on the reported breakfast question returns `basics_info`, not breakfast. Its knowledge JSON was English-only and retrieval filtered by client language.
- The older Node Bangla helpers already were bypassed by the exported FastAPI path. The recent repair did not newly remove that path.
- Checkpoint `89ed94f` has limited Bangla aliases. It misses the breakfast inflection `নাস্তায়`; input and aliases also lacked consistent Unicode canonicalization. Its explicit unknown clarification exposes the earlier coverage gap.
- The engine trusts valid client `en` over Bangla script. Protected generation is accepted only in English, and failed generation returns English evidence.
- Live reproduction before reload confirmed unknown/no retrieval for the original question with both client languages. The response was Bangla with `bn`, English with `en`.

## Narrow changes

`assistant_policy.py`: normalize aliases, add common Bangla inflections and mixed-language terms to existing routes, prefer Bangla script over the client language, and preserve Bangla negation in safety checks. English route rules remain unchanged.

`assistant_bangla.py` (new): complete display translations bound to exact prepared English source passages. They cover breakfast, management/self-care, HbA1c definition, foot complications and depression; exercise low-glucose text reuses existing bilingual safety copy. No knowledge records or thresholds were added. Changed source text invalidates its translation.

`assistant_engine.py`: use effective script language, apply bound translations after evidence selection, preserve complete protected text in either language, and record translation provenance in existing structured evidence metadata. Complete Bangla evidence remains usable when Ollama fails. If a safe translation is unavailable, return a Bangla clarification.

`test_bangla.py` (new), `test_regression.py`, `test_review_repairs.py`: new coverage and replacement of earlier English-fallback assumptions.

`manual_review_bangla.json` (new): before responses and all 22 final targeted live answers. This report is the eighth changed file.

## Before/after behavior

| Question family | Checkpoint problem | Current behavior |
| --- | --- | --- |
| Breakfast, including `নাস্তায়` / `নাশতায়` | Unknown; no retrieval | Breakfast retrieval, `nutrition_en_301`, complete Bangla answer |
| Diabetes/glucose control, including mixed English | Missing Bangla control vocabulary | Management evidence and Bangla answer |
| HbA1c definition / target | Transliteration gap and English protected fallback | Bangla definition; target clarification preserved |
| Tiredness / doctor contact | Missing inflections | Bangla clarification with existing safety language |
| Low glucose / insulin units or dose changes | Incomplete Bangla phrasing | Deterministic existing safety route in Bangla |
| Insulin usage | Missing usage phrasing | Existing insulin safety guidance in Bangla |
| Foot wounds | Missing Bangla topic terms / English protected fallback | Relevant foot evidence, causal qualifications preserved in Bangla |
| Depression | Protected translation rejected | Complete Bangla evidence retaining professional and emergency escalation |
| Unknown Bangla with client `en` | English clarification | Bangla clarification |

## Verification

- Python unit/regression/contract suite: **44/44 passed**, including 63 in-process POST cases (21 questions × three client language values), Unicode variants, safety bypass, source binding and lossy generation rejection.
- English-script fixture comparison with checkpoint policy: **77/77 intents unchanged**.
- Offline focused evaluation: **30/30**, safety **18/18**.
- Offline benchmark: **68/68**, expected evidence **48/48**. These evaluations use mocked candidate retrieval; they are not new live English benchmark results.
- Node chatbot integration: **5/5**.
- Targeted live evaluation after local API reload: **22/22**; 7 evidence fallbacks, 2 generated answers, 4 clarifications, 9 safety responses. Both client languages pass the originally reported breakfast question. Some generation calls logged `ReadTimeout`; usable Bangla evidence survived. No timeout/model changes.
- `git diff --check` passed. Knowledge JSON hash unchanged. No Chroma rebuild or embedding generation was performed. Normal database access changed three ignored runtime files (`chroma.sqlite3`, active index `data_level0.bin`, `length.bin`); those were not manually edited or restored.

## Limits

This is not clinical validation. New Bangla display translations are explicitly marked unreviewed in provenance and require bilingual clinical review. Vocabulary is representative, not exhaustive. Protected source passages without a bound translation may return Bangla clarification rather than a substantive answer. `knowledge_language=en` remains correct because the source corpus is English.

No paid API, deployment, Flutter/authentication/configuration change, knowledge edit or Chroma rebuild is required. Ready for targeted Android integration testing, with clinical/translation review still outstanding.
