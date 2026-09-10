"""Dependency-injected production answer path; safe to import in offline tests."""
import math
import re
import logging
import time

from assistant_copy import COPY, COPY_EVIDENCE, CLARIFICATIONS, MISSING_EVIDENCE
from assistant_evidence import (VERBATIM_CONTRACT, add_assessment_evidence,
                                prepare_evidence, symptoms_need_assessment)
from assistant_policy import TOPICS, contains, detect_intent, normalize_text, safety_decision

STOP_WORDS = set('what which when why how is are does do can should could i my me a an the to for of with in on and or it have get type diabetes glucose'.split())
LOGGER = logging.getLogger(__name__)
INTERNAL_ANSWER_TERMS = (
    'generation unavailable', 'generation not accepted', 'relevant diasm evidence',
    'generation_rejected', 'generation_unavailable', 'generation_not_answerable',
    'evidence_fallback', 'response_mode', 'fallback_reason',
)
A1C_DEFINITION = 'The A1C test measures your average blood sugar level over the past two to three months.'


def contains_internal_terminology(answer):
    return any(term in answer.casefold() for term in INTERNAL_ANSWER_TERMS)


SAFETY_CONSTRAINTS = (
    'Do not diagnose the user or recommend, calculate, increase, or change a personalized insulin dose. '
    'Do not invent medical facts, numbers, or personal treatment targets. '
    'Distinguish general diagnostic ranges from individual treatment targets. '
    'Do not infer pregnancy, age, sex, or a diagnosis. Preserve all evidence qualifications. '
    'If evidence cannot answer safely, ask one focused clarification.'
)


def keywords(text):
    return set(normalize_text(text).split()) - STOP_WORDS


def rank_candidates(query, intent, candidates):
    """Distances contribute ranking, not a claimed calibrated confidence threshold.

    Focused title facets gate action-specific questions. Generic queries require
    meaningful query overlap. Expanding categories never relaxes these gates.
    """
    facets = TOPICS.get(intent, ([], '', []))[2]
    normalized_query = normalize_text(query)
    if intent == 'basics_info' and contains(normalized_query, ['what is']):
        if contains(normalized_query, ['prediabetes']):
            facets = ['prediabetes']
        elif contains(normalized_query, ['glucose']):
            facets = ['what glucose does']
        elif contains(normalized_query, ['diabetes']):
            facets = ['what diabetes is', 'what type 2 diabetes is']
    if intent == 'exercise_guidance':
        if contains(normalized_query, ['when', 'after meals', 'best time']):
            facets = ['best time', 'timing']
        elif contains(normalized_query, ['beginner', 'start']):
            facets = ['beginner', 'start exercise']
    if intent == 'nutrition_general':
        for term in ['fruit', 'protein', 'portion', 'snack', 'lunch', 'dinner']:
            if contains(normalized_query, [term, term + 's']):
                facets = [term, term + 's']
                break
    terms = keywords(query)
    ranked = []
    seen = set()
    for candidate in candidates:
        if candidate['id'] in seen:
            continue
        seen.add(candidate['id'])
        title = normalize_text(candidate['metadata'].get('title', ''))
        document = normalize_text(candidate['document'])
        title_terms, doc_terms = keywords(title), keywords(document)
        exact_topic = contains(title, facets) if facets else False
        overlap = terms & (title_terms | doc_terms)
        if (facets and not exact_topic) or (not facets and not overlap):
            continue
        distance = candidate.get('distance')
        semantic = 1 / (1 + max(0, distance)) if isinstance(distance, (int, float)) and math.isfinite(distance) else 0
        lexical = len(terms & title_terms) / max(1, len(terms)) + 0.5 * len(terms & doc_terms) / max(1, len(terms))
        score = 2 * exact_topic + lexical + 0.5 * semantic
        ranked.append({**candidate, 'score': round(score, 4), 'semantic_relevance': round(semantic, 4)})
    return sorted(ranked, key=lambda r: (-r['score'], r['id']))


def build_clean_answer(evidence):
    # Keep meaningful short sentences, negation, units and safety qualifications.
    seen, parts = set(), []
    for item in evidence:
        for sentence in re.split(r'(?<=[.!?।])\s+', item['document'].strip()):
            if sentence and sentence.casefold() not in seen:
                seen.add(sentence.casefold())
                parts.append(sentence)
    return ' '.join(parts)


def generation_is_usable(output, evidence, intent, language):
    """Conservative structural/topic checks, NOT a clinical or entailment validator."""
    if not isinstance(output, dict) or output.get('answerable') is not True:
        return False
    answer, ids = output.get('answer'), output.get('evidence_ids')
    if not isinstance(answer, str) or not answer.strip() or not isinstance(ids, list) or not ids:
        return False
    if contains_internal_terminology(answer):
        return False
    if not all(isinstance(i, str) for i in ids) or len(ids) != len(set(ids)):
        return False
    supplied = {r['id']: r for r in evidence}
    if not set(ids) <= supplied.keys():
        return False
    if any(r.get('preserve_text') for r in evidence):
        # Keywords cannot establish that escalation, negation, or causal meaning
        # survived a rewrite. These reviewed passages require exact text fidelity.
        return (language == 'en' and set(ids) == supplied.keys()
                and ' '.join(answer.split()) == ' '.join(build_clean_answer(evidence).split()))
    cited = ' '.join(supplied[i]['document'] for i in ids)
    a, source = normalize_text(answer), normalize_text(cited)
    if re.search(r'\b\d+(?:\.\d+)?\s*(?:units?|iu)\b', answer, re.I):
        return False
    if contains(a, ['increase insulin', 'double insulin', 'change your dose', 'take extra insulin']):
        return False
    if contains(a, ['insulin']) and contains(a, ['units', 'dose']):
        # Dose-related requests are deterministic; ordinary generated answers
        # must not introduce dosing instructions, including translated ones.
        return False
    for topic in ['gestational', 'pregnancy', 'remission', 'prediabetes']:
        if contains(a, [topic]) and not contains(source, [topic]):
            return False
    # Do not introduce new quantities, including in Bangla translations.
    def numbers(text):
        import unicodedata
        text = ''.join(str(unicodedata.digit(c)) if c.isdigit() else c for c in text)
        return set(re.findall(r'\d+(?:\.\d+)?', text))
    if not numbers(answer) <= numbers(cited):
        return False
    if language == 'bn':
        return bool(re.search('[\u0980-\u09ff]', answer))
    if re.search('[\u0980-\u09ff]', answer):
        return False
    topic_words = {
        'breakfast_suggestions': ['breakfast'], 'foods_to_limit': ['avoid', 'limit'],
        'glucose_management': ['manage', 'managed', 'management', 'control', 'eating', 'exercise'],
        'hba1c_definition': ['hba1c'], 'hba1c_diagnostic_range': ['hba1c'],
        'care_seeking': ['doctor', 'healthcare', 'professional'], 'prevention_info': ['prevent', 'prevented', 'prevention', 'delayed'],
    }
    if intent in topic_words and not contains(a, topic_words[intent]):
        return False
    if intent == 'glucose_management':
        actions = [['healthy eating', 'eat', 'eating'], ['exercise', 'activity', 'walking'],
                   ['monitoring', 'monitor', 'checking'], ['weight control', 'weight management']]
        if sum(contains(a, group) for group in actions) < 2:
            return False
    return len(keywords(answer) & keywords(cited)) >= 2


class Assistant:
    def __init__(self, retrieve, generate, knowledge):
        self.retrieve = retrieve
        self.generate = generate
        self.knowledge = {row['id']: row for row in knowledge}

    def _response(self, answer, intent, language, mode, evidence=(), retrieval=False, **extra):
        ids = [r['id'] for r in evidence]
        # A narrow grammar normalization, only after the supporting record is used.
        if intent == 'hba1c_definition' and language == 'en' and 'type2_en_019' in ids:
            answer = A1C_DEFINITION
        categories = sorted({r['metadata']['category'] for r in evidence})
        return dict(answer=answer, intent=intent, language=language,
                    requested_language=language, response_mode=mode,
                    evidence_ids=ids, retrieved_ids=ids if retrieval else [],
                    retrieval_performed=retrieval, retrieval_attempted=retrieval, category=categories[0] if categories else None,
                    categories=categories, knowledge_language='en',
                    clinical_review_required=any(r.get('preserve_text') for r in evidence),
                    **extra)

    def _direct(self, intent, language):
        ids = COPY_EVIDENCE.get(intent, [])
        evidence = [dict(id=i, metadata={'category': self.knowledge[i]['category']}) for i in ids if i in self.knowledge]
        result = self._response(COPY[intent][language == 'bn'], intent, language,
                                'clarification' if intent in CLARIFICATIONS else 'safety', evidence)
        result['clinical_review_required'] = intent != 'unknown'
        result['safety_copy_version'] = 'focused-repair-v1-unreviewed' if intent != 'unknown' else None
        return result

    def _prepare(self, row, intent, question=''):
        """Use existing focused Q&A where available, without changing the index."""
        source = self.knowledge.get(row['id'], {})
        if intent == 'hba1c_definition' and row['id'] == 'type2_en_019':
            for qa in source.get('qa_pairs', []):
                if normalize_text(qa['question']) == 'what is the hba1c test':
                    return {**row, 'document': qa['answer']}
        return prepare_evidence(row, intent, question, source)

    def _clarify(self, intent, language, reason, retrieval):
        result = self._direct('unknown', language)
        if intent in MISSING_EVIDENCE:
            result['answer'] = MISSING_EVIDENCE[intent][language == 'bn']
        result.update(intent=intent, retrieval_performed=retrieval, retrieval_attempted=True, fallback_reason=reason)
        return result

    def answer(self, question, language='en'):
        question = (question or '').strip()
        language = language if language in ('en', 'bn') else ('bn' if re.search('[\u0980-\u09ff]', question) else 'en')
        normalized = normalize_text(question)
        intent = safety_decision(question) or detect_intent(question)
        if intent in COPY:
            return self._direct(intent, language)
        categories, rewrite, _ = TOPICS.get(intent, ([], '', []))
        standalone = (normalized + ' ' + rewrite).strip()
        candidates, retrieval_error, retrieval_performed = [], None, False
        try:
            candidates = self.retrieve(standalone, categories)
            retrieval_performed = True
            ranked = rank_candidates(question, intent, candidates)
            if not ranked and categories:
                candidates = self.retrieve(standalone, [])
                ranked = rank_candidates(question, intent, candidates)
        except Exception as exc:
            retrieval_error = type(exc).__name__
            ranked = []
        if not ranked:
            return self._clarify(intent, language, 'retrieval_unavailable' if retrieval_error else 'insufficient_alignment', retrieval_performed)
        # Narrow questions should not acquire generic adjacent topics merely to fill k.
        selected = [r for r in ranked[:3] if r['score'] >= ranked[0]['score'] - 0.35]
        if symptoms_need_assessment(question, intent):
            selected = add_assessment_evidence(selected, self.knowledge)
        selected = [self._prepare(r, intent, question) for r in selected]
        preserve_text = any(r.get('preserve_text') for r in selected)
        payload = dict(question=question, normalized_question=standalone, language=language,
                       evidence=[{'id': r['id'], 'text': r['document'], 'title': r['metadata']['title']} for r in selected],
                       intent=intent, safety_constraints=SAFETY_CONSTRAINTS,
                       answer_contract=VERBATIM_CONTRACT if preserve_text else 'Answer from the supplied evidence.')
        evidence_metadata = {
            'evidence_sources': {r['id']: {'fields': r.get('source_fields', ['retrieval_text']),
                                          'origin': r.get('evidence_origin', 'retrieved_record')}
                                 for r in selected},
        } if preserve_text else {}
        if any(r['id'] == 'exercise_en_008' for r in selected):
            evidence_metadata['safety_copy_version'] = 'focused-repair-v1-unreviewed'
        fallback_reason = 'generation_unavailable'
        generation_diagnostics = {}
        generation_started = time.monotonic()
        try:
            output = self.generate(**payload)
            if generation_is_usable(output, selected, intent, language):
                used = [r for r in selected if r['id'] in output['evidence_ids']]
                return self._response(output['answer'].strip(), intent, language, 'generated', used, True,
                                      manual_review_required=True, **evidence_metadata)
            fallback_reason = 'generation_not_answerable' if isinstance(output, dict) and output.get('answerable') is False else 'generation_rejected'
            if fallback_reason == 'generation_not_answerable' and not preserve_text:
                return self._clarify(intent, language, fallback_reason, True)
        except Exception as exc:
            generation_diagnostics = {
                'generation_error_type': type(exc).__name__,
                'generation_elapsed_ms': round((time.monotonic() - generation_started) * 1000),
            }
            # No question, evidence or exception message (which may contain user data).
            LOGGER.warning('Ollama generation failed: %s', generation_diagnostics)
        # Failure details stay in metadata/logs; the user gets only the clean answer.
        result = self._response(build_clean_answer(selected), intent, 'en', 'evidence_fallback', selected, True,
                                fallback_reason=fallback_reason, translation_unavailable=language == 'bn',
                                **generation_diagnostics, **evidence_metadata)
        result['requested_language'] = language
        return result
