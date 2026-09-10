"""Offline production-policy tests: no model imports or vector-store writes."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from assistant_engine import Assistant, build_clean_answer, rank_candidates, contains_internal_terminology, A1C_DEFINITION
from assistant_policy import detect_intent, normalize_text, safety_decision

ROOT = Path(__file__).resolve().parent
KB = json.loads((ROOT.parent / 'ai-data/knowledge_base.json').read_text(encoding='utf-8'))
CASES = json.loads((ROOT / 'regression_cases.json').read_text(encoding='utf-8'))


class CorpusRetriever:
    """Mock candidate search with reversed corpus order; not a semantic benchmark."""
    def __init__(self):
        self.calls = []

    def __call__(self, query, categories):
        self.calls.append((query, categories))
        return [dict(id=r['id'], document=r['retrieval_text'],
                     metadata=dict(title=r['section_title'], category=r['category'], language=r['language']),
                     distance=0.8)
                for r in reversed(KB) if not categories or r['category'] in categories]


def unavailable(**kwargs):
    raise ConnectionError('mock Ollama unavailable')


class RegressionTests(unittest.TestCase):
    def setUp(self):
        logger = patch('assistant_engine.LOGGER')
        self.logger = logger.start()
        self.addCleanup(logger.stop)
        self.retriever = CorpusRetriever()
        self.assistant = Assistant(self.retriever, unavailable, KB)

    def test_original_twelve(self):
        for case in CASES:
            with self.subTest(question=case['question']):
                result = self.assistant.answer(case['question'], 'en')
                self.assertFalse(contains_internal_terminology(result['answer']))
                self.assertEqual(result['intent'], case['intent'])
                self.assertEqual(result['response_mode'], case['mode'])
                if case['evidence']:
                    self.assertIn(case['evidence'], result['evidence_ids'])
                else:
                    self.assertEqual(result['evidence_ids'], [])
                self.assertLessEqual(len(result['evidence_ids']), 3)
                forbidden_topics = ['gestational', 'remission']
                if case['intent'] != 'prevention_info':
                    forbidden_topics.append('prediabetes')
                for forbidden in forbidden_topics:
                    self.assertNotIn(forbidden, result['answer'].lower())
                self.assertEqual(result['retrieved_ids'], result['evidence_ids'] if result['retrieval_performed'] else [])

    def test_aliases(self):
        for alias in ['hba1c', 'hb1ac', 'hb a1c', 'a1c', 'glycated hemoglobin', 'glycated haemoglobin']:
            self.assertEqual(detect_intent('what is ' + alias), 'hba1c_definition')
            self.assertEqual(detect_intent(alias + ' limit?'), 'hba1c_target_clarification')
            result = self.assistant.answer('what is ' + alias)
            self.assertEqual(result['response_mode'], 'evidence_fallback')
            self.assertEqual(result['evidence_ids'], ['type2_en_019'])
            self.assertNotIn('prediabetes', result['answer'].lower())
        for term in ['blood sugar', 'blood glucose', 'glucose']:
            self.assertEqual(detect_intent('how to manage ' + term), 'glucose_management')
            result = self.assistant.answer('how to manage ' + term)
            self.assertEqual(result['response_mode'], 'evidence_fallback')
            self.assertIn('type2_en_008', result['evidence_ids'])
        for term in ['high sugar', 'hyperglycemia', 'high blood glucose']:
            self.assertEqual(detect_intent('I have ' + term), 'high_glucose_actions')
            result = self.assistant.answer('I have ' + term)
            self.assertEqual(result['response_mode'], 'clarification')
            self.assertEqual(result['evidence_ids'], ['type2_en_018'])
        for term in ['low sugar', 'hypoglycemia', 'low blood glucose']:
            self.assertEqual(detect_intent('I have ' + term), 'low_glucose_actions')
            result = self.assistant.answer('I have ' + term)
            self.assertEqual(result['response_mode'], 'safety')
            self.assertEqual(result['evidence_ids'], ['exercise_en_008'])
        for term in ['doctor', 'physician', 'hospital', 'emergency']:
            self.assertEqual(detect_intent('when should I contact a ' + term), 'care_seeking')
            result = self.assistant.answer('when should I contact a ' + term)
            self.assertEqual(result['response_mode'], 'clarification')
            self.assertIn('type2_en_003', result['evidence_ids'])
            self.assertNotIn('gestational', result['answer'].lower())

    def test_bangla_and_mixed(self):
        for question, intent in [('সুগার কমে গেছে', 'low_glucose_actions'), ('রক্তে শর্করা বেশি', 'high_glucose_actions'),
                                  ('কখন ডাক্তার দেখাব', 'care_seeking'), ('amar sugar beshi ki korbo', 'high_glucose_actions'),
                                  ('blood sugar বেশি কি করব', 'high_glucose_actions')]:
            with self.subTest(question=question):
                result = self.assistant.answer(question, 'bn')
                self.assertEqual(result['intent'], intent)
                self.assertEqual(result['requested_language'], 'bn')
                if result['response_mode'] in ['safety', 'clarification']:
                    self.assertEqual(result['language'], 'bn')
                    self.assertRegex(result['answer'], '[\u0980-\u09ff]')
                else:
                    self.assertEqual(result['language'], 'en')
                    self.assertTrue(result['translation_unavailable'])
        self.assertEqual(normalize_text('অনুভূতি'), 'অনুভূতি')

    def test_safety_routes_bypass_retrieval_and_generation(self):
        cases = [('He is unconscious and his sugar is low', 'emergency_unconscious'),
                 ('I cannot swallow and my sugar is low', 'emergency_swallowing'),
                 ('I have breathing difficulty', 'emergency_breathing'),
                 ('My glucose is high and I cannot breathe', 'emergency_breathing'),
                 ('I have chest pain', 'emergency_chest_pain'), ('My blood sugar is very high', 'severe_high_glucose'),
                 ('I am pregnant and my sugar is high', 'pregnancy_concern'),
                 ('How many units of insulin should I take?', 'insulin_dose_request'),
                 ('Can I double my insulin dose?', 'insulin_dose_request'),
                 ('Calculate my insulin dose', 'insulin_dose_request'), ('Should I increase insulin?', 'insulin_dose_request'),
                 ('Recommend an insulin dose', 'insulin_dose_request'),
                 ('বুকে ব্যথা হচ্ছে', 'emergency_chest_pain'), ('শ্বাসকষ্ট হচ্ছে', 'emergency_breathing')]
        for question, intent in cases:
            with self.subTest(question=question):
                result = self.assistant.answer(question, 'en')
                self.assertEqual(result['intent'], intent)
                self.assertEqual(result['response_mode'], 'safety')
                self.assertTrue(result['clinical_review_required'])
                self.assertFalse(result['retrieval_performed'])
                self.assertNotRegex(result['answer'].lower(), r'\b\d+(?:\.\d+)?\s*(?:units?|iu)\b')
                if intent in ['emergency_unconscious', 'emergency_swallowing']:
                    self.assertIn('do not give', result['answer'].lower())
                    self.assertNotIn('15 grams', result['answer'])
        self.assertEqual(self.retriever.calls, [])

    def test_negation_education_and_boundaries(self):
        for question in ['I do not have chest pain', 'What does chest pain mean?', 'What is hypoglycemia?',
                         'I have no low sugar', 'He is not unconscious', 'What if someone cannot swallow?',
                         'What causes chest pain?', 'Is chest pain dangerous?']:
            self.assertIsNone(safety_decision(question), question)
        self.assertNotEqual(detect_intent('How do I breathe slowly?'), 'nutrition_general')
        self.assertEqual(detect_intent('What is the capital of France?'), 'unknown')
        self.assertEqual(detect_intent('hba1c diagnostic range'), 'hba1c_diagnostic_range')
        self.assertEqual(detect_intent('What should my hba1c target be?'), 'hba1c_target_clarification')
        self.assertEqual(safety_decision('He is not breathing'), 'emergency_breathing')
        self.assertEqual(safety_decision('I am pregnant and my sugar is low'), 'low_glucose_actions')

    def test_safety_fixture(self):
        for case in json.loads((ROOT / 'safety_cases.json').read_text(encoding='utf-8')):
            with self.subTest(question=case['question']):
                result = self.assistant.answer(case['question'], case.get('language', 'en'))
                self.assertEqual(result['intent'], case['intent'])
                self.assertEqual(result['response_mode'], 'safety')
                self.assertFalse(result['retrieval_performed'])

    def test_semantic_distance_and_failed_retrieval(self):
        base = dict(document='Breakfast with egg and vegetables.', metadata=dict(title='Breakfast', category='nutrition'))
        candidates = [dict(base, id='far', distance=5), dict(base, id='near', distance=0.1)]
        self.assertEqual(rank_candidates('breakfast', 'breakfast_suggestions', candidates)[0]['id'], 'near')
        def failed(*args):
            raise RuntimeError('mock model unavailable')
        result = Assistant(failed, unavailable, KB).answer('breakfast')
        self.assertEqual(result['response_mode'], 'clarification')
        self.assertTrue(result['retrieval_attempted'])
        self.assertFalse(result['retrieval_performed'])
        self.assertEqual(result['evidence_ids'], [])

    def test_bangla_generation_and_answerability(self):
        def bengali(**payload):
            return dict(answer='সকালের নাশতায় রুটি, ডিম ও সবজি খেতে পারেন।', evidence_ids=['nutrition_en_301'], answerable=True)
        result = Assistant(self.retriever, bengali, KB).answer('what can i eat for breakfast', 'bn')
        self.assertEqual(result['response_mode'], 'generated')
        self.assertEqual(result['language'], 'bn')
        def cannot_answer(**payload):
            return dict(answer='untrusted clarification', evidence_ids=[], answerable=False)
        result = Assistant(self.retriever, cannot_answer, KB).answer('what can i eat for breakfast')
        self.assertEqual(result['response_mode'], 'clarification')
        self.assertIn('breakfast', result['answer'])
        self.assertEqual(result['evidence_ids'], [])

    def test_relevance_gate_and_expansion(self):
        unrelated = dict(id='general_en_005', document='Gestational diabetes develops during pregnancy.',
                         metadata=dict(title='Gestational Diabetes', category='basics'), distance=0.01)
        calls = []
        def bad_search(query, categories):
            calls.append(categories)
            return [unrelated]
        result = Assistant(bad_search, unavailable, KB).answer('what can i eat for breakfast')
        self.assertEqual(result['response_mode'], 'clarification')
        self.assertEqual(result['evidence_ids'], [])
        self.assertNotIn('gestational', result['answer'].lower())
        self.assertEqual(calls[-1], [])

    def test_specific_topic_beats_generic_diet(self):
        candidates = self.retriever('breakfast', ['nutrition'])
        for question, intent, expected in [('what can i eat for breakfast', 'breakfast_suggestions', 'nutrition_en_301'),
                                            ('what foods should I avoid', 'foods_to_limit', 'nutrition_en_102')]:
            self.assertEqual(rank_candidates(question, intent, candidates)[0]['id'], expected)

    def test_preserves_short_sentences(self):
        self.assertIn('Avoid biscuits and sweets.', build_clean_answer([{'document': 'Avoid biscuits and sweets.'}]))

    def test_existing_definitions_still_have_evidence(self):
        for question, expected in [('what is diabetes', 'general_en_001'), ('what is blood glucose', 'general_en_003')]:
            result = self.assistant.answer(question)
            self.assertEqual(result['response_mode'], 'evidence_fallback')
            self.assertIn(expected, result['evidence_ids'])

    def test_generation_contract_and_source_ids(self):
        captured = {}
        def generator(**payload):
            captured.update(payload)
            return {'answer': 'Breakfast can include ruti with egg and vegetables.', 'evidence_ids': ['nutrition_en_301'], 'answerable': True}
        result = Assistant(self.retriever, generator, KB).answer('what can i eat for breakfast', 'en')
        self.assertEqual(result['response_mode'], 'generated')
        self.assertEqual(result['evidence_ids'], ['nutrition_en_301'])
        for field in ['question', 'normalized_question', 'language', 'evidence', 'intent', 'safety_constraints']:
            self.assertIn(field, captured)

    def test_untrusted_generation_falls_back(self):
        for generated in [dict(answer='Gestational diabetes develops during pregnancy.', evidence_ids=['nutrition_en_301'], answerable=True),
                          dict(answer='Take 10 units of insulin.', evidence_ids=['nutrition_en_301'], answerable=True),
                          dict(answer='Breakfast advice.', evidence_ids=['invented'], answerable=True)]:
            result = Assistant(self.retriever, lambda **kw: generated, KB).answer('what can i eat for breakfast')
            self.assertEqual(result['response_mode'], 'evidence_fallback')
            self.assertIn('nutrition_en_301', result['evidence_ids'])
            self.assertNotIn(generated['answer'], result['answer'])
        insulin_definition = dict(answer='Insulin helps control blood sugar.', evidence_ids=['type2_en_008'], answerable=True)
        result = Assistant(self.retriever, lambda **kw: insulin_definition, KB).answer('how to manage blood sugar')
        self.assertEqual(result['response_mode'], 'evidence_fallback')
        self.assertNotEqual(result['answer'], insulin_definition['answer'])

    def test_internal_terminology_never_reaches_answers(self):
        from assistant_engine import INTERNAL_ANSWER_TERMS
        for phrase in INTERNAL_ANSWER_TERMS:
            for language in ['en', 'bn']:
                def contaminated(**payload):
                    return dict(answer=phrase + ': Breakfast can include egg and vegetables.',
                                evidence_ids=['nutrition_en_301'], answerable=True)
                result = Assistant(self.retriever, contaminated, KB).answer('what can i eat for breakfast', language)
                self.assertFalse(contains_internal_terminology(result['answer']))
                self.assertEqual(result['response_mode'], 'evidence_fallback')
                self.assertEqual(result['fallback_reason'], 'generation_rejected')
                self.assertTrue(result['answer'].startswith('For breakfast in diabetes'))
        result = self.assistant.answer('what can i eat for breakfast')
        self.assertFalse(contains_internal_terminology(result['answer']))
        self.assertEqual(result['generation_error_type'], 'ConnectionError')
        self.assertGreaterEqual(result['generation_elapsed_ms'], 0)
        self.logger.warning.assert_called()

    def test_hba1c_grammar_and_target_are_stable(self):
        def poor_grammar(**payload):
            return dict(answer='The A1C test average blood sugar over the past two to three months.',
                        evidence_ids=['type2_en_019'], answerable=True)
        for generate in [unavailable, poor_grammar]:
            result = Assistant(self.retriever, generate, KB).answer('what is hb1ac?')
            self.assertEqual(result['answer'], A1C_DEFINITION)
            self.assertEqual(result['evidence_ids'], ['type2_en_019'])
        result = self.assistant.answer('hb1ac limit?')
        self.assertEqual(result['answer'], 'Do you mean the HbA1c range used for diagnosis, or your own treatment target? I can explain the diagnostic information, but your personal target needs guidance from your diabetes clinician.')
        self.assertEqual(result['response_mode'], 'clarification')
        self.assertEqual(result['evidence_ids'], [])

    def test_broad_care_clarification_and_emergency_precedence(self):
        result = self.assistant.answer('when should i get to doctors?')
        self.assertEqual(result['response_mode'], 'clarification')
        self.assertIn('routine diabetes follow-up', result['answer'])
        self.assertIn('urgent symptom', result['answer'])
        for red_flag in ['chest pain', 'breathing difficulty', 'fainting', 'difficulty staying awake']:
            self.assertIn(red_flag, result['answer'])
        self.assertFalse(result['retrieval_performed'])
        self.assertTrue(result['clinical_review_required'])
        result = self.assistant.answer('I have chest pain, should I see a doctor?')
        self.assertEqual(result['intent'], 'emergency_chest_pain')
        self.assertEqual(result['response_mode'], 'safety')


if __name__ == '__main__':
    unittest.main()
