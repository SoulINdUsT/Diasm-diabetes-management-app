"""Regression coverage for all nine live review findings, without live services."""
import unittest
from unittest.mock import patch

from assistant_copy import COPY
from assistant_engine import Assistant, build_clean_answer, contains_internal_terminology
from assistant_evidence import VERBATIM_CONTRACT, prepare_evidence, qa_answer
from test_regression import KB, CorpusRetriever, unavailable


SOURCES = {r['id']: r for r in KB}
CASES = [
    ('Can diabetes be cured?', ['basics_en_027'],
     'Diabetes is generally not completely curable, but some people with type 2 diabetes may go into remission.'),
    ('What if sugar drops during workout?', ['exercise_en_008'],
     'Stop the activity right away and treat the low sugar. Take 15 grams of fast-acting carbohydrate such as glucose tablets or juice, wait 15 minutes, and recheck blood sugar if possible.'),
    ('Why am I always hungry?', ['nutrition_en_307'],
     'Eating regular meals with protein, adding vegetables, and choosing snacks like peanuts or boiled egg can help control hunger in diabetes. Avoid skipping meals and large carbohydrate-only meals.'),
    ('I feel depressed', ['mental_en_006'],
     'Start with one small action such as drinking water, taking 10 slow breaths, eating a simple meal, checking blood sugar, or taking a short walk.'),
    ('I am always thirsty and urinate a lot, should I get tested?', ['type2_en_002', 'type2_en_005'],
     "The symptoms you described are common in type 2 diabetes, but it's recommended to get tested to confirm the diagnosis."),
    ('What happens if diabetes is not treated for years?', ['complications_en_002'],
     'Diabetes complications damages the body.'),
    ('Why is protein in urine dangerous for diabetic patients?', ['type2_en_032'],
     'Protein in urine can be a sign of diabetic nephropathy, which can lead to kidney damage and reduced ability to filter waste.'),
    ('Why are foot wounds risky in diabetes?', ['complications_en_413', 'type2_en_034'],
     'Foot wounds are risky in diabetes because they can lead to unnoticed injuries, infections, ulcers, and in severe cases, amputation, due to reduced blood flow and damaged nerves.'),
    ('What precautions should I take before exercise?', ['exercise_en_005', 'exercise_en_010'],
     'Check your blood sugar levels before exercise and aim for a level between 100 and 250 mg/dL.'),
]


def candidate(source_id):
    source = SOURCES[source_id]
    return dict(id=source_id, document=source['retrieval_text'], distance=0.8,
                metadata=dict(title=source['section_title'], category=source['category']))


class ReviewRepairTests(unittest.TestCase):
    def setUp(self):
        logger = patch('assistant_engine.LOGGER')
        logger.start()
        self.addCleanup(logger.stop)

    def run_case(self, index, generate=unavailable, language='en'):
        question, ids, _ = CASES[index]
        return Assistant(lambda q, cats: [candidate(i) for i in ids], generate, KB).answer(question, language)

    def test_all_nine_reject_original_lossy_answers(self):
        for index, (question, _, old_answer) in enumerate(CASES):
            with self.subTest(question=question):
                def lossy(**payload):
                    self.assertEqual(payload['answer_contract'], VERBATIM_CONTRACT)
                    return dict(answerable=True, answer=old_answer,
                                evidence_ids=[r['id'] for r in payload['evidence']])
                result = self.run_case(index, lossy)
                self.assertEqual(result['response_mode'], 'evidence_fallback')
                self.assertEqual(result['fallback_reason'], 'generation_rejected')
                self.assertNotEqual(result['answer'], old_answer)
                self.assertTrue(result['clinical_review_required'])
                self.assertFalse(contains_internal_terminology(result['answer']))
                self.assertEqual(result['answer'], self.run_case(index)['answer'])

    def test_all_nine_accept_complete_evidence_and_reject_additions_or_missing_ids(self):
        for index, (question, _, _) in enumerate(CASES):
            for defect in [None, 'addition', 'missing_id', 'not_answerable', 'internal']:
                with self.subTest(question=question, defect=defect):
                    def generate(**payload):
                        evidence = [dict(id=r['id'], document=r['text']) for r in payload['evidence']]
                        answer = build_clean_answer(evidence)
                        ids = [r['id'] for r in evidence]
                        if defect == 'addition':
                            answer += ' You have diabetes.'
                        if defect == 'missing_id':
                            ids = ids[:-1]
                        if defect == 'internal':
                            answer += ' generation_unavailable'
                        return dict(answerable=defect != 'not_answerable', answer=answer, evidence_ids=ids)
                    result = self.run_case(index, generate)
                    self.assertEqual(result['response_mode'], 'generated' if defect is None else 'evidence_fallback')
                    self.assertEqual(result['answer'], self.run_case(index)['answer'])

    def test_remission_monitoring(self):
        self.assertEqual(self.run_case(0)['answer'], SOURCES['basics_en_027']['retrieval_text'])
        self.assertIn('regular monitoring', self.run_case(0)['answer'])
        self.assertIn('does not mean the disease is permanently gone', self.run_case(0)['answer'])

    def test_exercise_low_glucose_preserves_existing_safety_boundary(self):
        result = self.run_case(1)
        self.assertEqual(result['answer'], COPY['low_glucose_actions'][0])
        self.assertIn('Do not resume exercise until symptoms improve and blood sugar is safer.', result['answer'])
        self.assertIn('If awake and able to swallow', result['answer'])
        self.assertIn('do not give anything by mouth', result['answer'])
        self.assertIn('assistant_copy.COPY.low_glucose_actions.en',
                      result['evidence_sources']['exercise_en_008']['fields'])

    def test_hunger_explanation_is_supplied_before_management(self):
        answer = qa_answer(SOURCES['nutrition_en_307'], 'Why do I feel hungry all the time?')
        row = prepare_evidence(candidate('nutrition_en_307'), 'nutrition_hunger_management',
                               CASES[2][0], SOURCES['nutrition_en_307'])
        self.assertTrue(row['document'].startswith(answer))
        self.assertTrue(self.run_case(2)['answer'].startswith(answer))
        self.assertIn('may', answer)

    def test_depression_preserves_both_escalations(self):
        answer = self.run_case(3)['answer']
        self.assertEqual(answer, SOURCES['mental_en_006']['retrieval_text'])
        self.assertIn('get professional help', answer)
        self.assertIn('risk of harming yourself or others, seek emergency help immediately', answer)

    def test_symptoms_testing_gets_assessment_evidence_without_diagnosis_or_cutoffs(self):
        result = self.run_case(4)
        self.assertEqual(result['intent'], 'symptoms_risk')
        self.assertEqual(result['evidence_ids'], ['type2_en_002', 'type2_en_003', 'type2_en_006'])
        self.assertIn(SOURCES['type2_en_003']['retrieval_text'], result['answer'])
        self.assertIn(qa_answer(SOURCES['type2_en_006'], 'How is type 2 diabetes diagnosed?'), result['answer'])
        self.assertNotIn('confirm the diagnosis', result['answer'])
        self.assertNotIn('%', result['answer'])
        self.assertEqual(result['evidence_sources']['type2_en_006']['origin'], 'knowledge_supplement')

    def test_untreated_diabetes_retains_source_grammar(self):
        self.assertEqual(self.run_case(5)['answer'], SOURCES['complications_en_002']['retrieval_text'])
        self.assertNotIn('complications damages', self.run_case(5)['answer'])

    def test_proteinuria_signs_are_in_the_actual_prompt_evidence(self):
        seen = {}
        def capture(**payload):
            seen.update(payload)
            return None
        result = self.run_case(6, capture)
        source_answer = qa_answer(SOURCES['type2_en_032'], 'What are signs of kidney damage in diabetes?')
        self.assertIn(source_answer, seen['evidence'][0]['text'])
        self.assertIn(source_answer, result['answer'])
        self.assertIn('reduces their ability to filter waste', result['answer'])

    def test_foot_causality_survives_generation(self):
        answer = self.run_case(7)['answer']
        self.assertIn('poor circulation slows healing', answer)
        self.assertIn('reduced protective sensation allows small injuries to be missed', answer)
        self.assertNotIn('Foot wounds are risky in diabetes because they can lead to unnoticed injuries', answer)

    def test_exercise_precautions_supply_no_personal_target(self):
        seen = {}
        def capture(**payload):
            seen.update(payload)
            return None
        answer = self.run_case(8, capture)['answer']
        for text in [answer] + [r['text'] for r in seen['evidence']]:
            self.assertNotRegex(text, r'\d')
            self.assertNotIn('aim for', text)
        self.assertIn('Avoid exercise if sugar is too low or very high.', answer)
        self.assertIn(SOURCES['exercise_en_010']['description'], answer)

    def test_paraphrases_and_unrelated_routes(self):
        assistant = Assistant(CorpusRetriever(), unavailable, KB)
        for question, expected in [
            ('Why do I feel hungry all the time?', 'nutrition_en_307'),
            ('Why is protein in urine a concern?', 'type2_en_032'),
            ('I feel hopeless', 'mental_en_006'),
            ('What if blood glucose drops during exercise?', 'exercise_en_008'),
            ('I am thirsty, do I need testing?', 'type2_en_003'),
        ]:
            with self.subTest(question=question):
                result = assistant.answer(question)
                self.assertIn(expected, result['evidence_ids'])
                self.assertTrue(result['clinical_review_required'])
        # An unrelated ordinary generated answer is still accepted.
        def generate(**payload):
            return dict(answerable=True, answer=payload['evidence'][0]['text'],
                        evidence_ids=[payload['evidence'][0]['id']])
        result = Assistant(CorpusRetriever(), generate, KB).answer('What should I eat for breakfast?')
        self.assertEqual(result['response_mode'], 'generated')
        self.assertFalse(result['clinical_review_required'])

    def test_protected_english_is_not_mislabeled_as_a_bangla_translation(self):
        def translated(**payload):
            return dict(answerable=True, answer='বিষণ্ণ হলে পানি পান করুন।',
                        evidence_ids=[r['id'] for r in payload['evidence']])
        result = self.run_case(3, translated, 'bn')
        self.assertEqual(result['language'], 'en')
        self.assertEqual(result['requested_language'], 'bn')
        self.assertTrue(result['translation_unavailable'])
        self.assertIn('seek emergency help immediately', result['answer'])


if __name__ == '__main__':
    unittest.main()
