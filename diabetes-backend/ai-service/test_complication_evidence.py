"""Regression checks for evidence equivalence, not medical validation."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from assistant_engine import Assistant, rank_candidates
from assistant_policy import TOPICS, detect_intent
from evaluate import assess_result, manual_review_rows
from test_regression import CorpusRetriever, KB, unavailable

ROOT = Path(__file__).resolve().parent
QUESTION = 'Can uncontrolled diabetes harm my organs?'


class ComplicationEvidenceTests(unittest.TestCase):
    def test_benchmark_review_retains_all_answers(self):
        rows = [dict(question=str(i), failures=[]) for i in range(68)]
        rows[-1]['failures'] = ['evidence']
        self.assertEqual(manual_review_rows(rows, 'benchmark'), rows)
        self.assertEqual(manual_review_rows(rows, 'focused'), rows)

    def test_equivalent_organ_evidence_is_accepted_but_unrelated_definition_is_not(self):
        items = json.loads((ROOT / 'evaluation_questions.json').read_text(encoding='utf-8'))
        item = next(row for row in items if row['question'] == QUESTION)
        for source in ['complications_en_101', 'complications_en_414']:
            result = dict(answer='Yes, uncontrolled diabetes can harm your organs.',
                          intent='complications_general', categories=['complications'],
                          evidence_ids=[source], retrieved_ids=[source], retrieval_performed=True,
                          response_mode='generated')
            self.assertEqual(assess_result(item, result)['checks'], 'CHECKS_PASS')
        result.update(evidence_ids=['general_en_001'], retrieved_ids=['general_en_001'], categories=['basics'])
        self.assertIn('evidence', assess_result(item, result)['failures'])

    def test_general_and_specific_organ_questions_keep_relevant_evidence(self):
        cases = [
            (QUESTION, 'complications_general', {'complications_en_101', 'complications_en_414'}),
            ('Can uncontrolled diabetes damage my eyes?', 'complications_eyes', {'type2_en_030', 'complications_en_410'}),
            ('Can uncontrolled diabetes damage my kidneys?', 'complications_kidneys', {'type2_en_032'}),
            ('Can uncontrolled diabetes cause nerve damage?', 'complications_nerves', {'type2_en_031', 'complications_en_411'}),
            ('Can uncontrolled diabetes damage my heart?', 'complications_heart_vessels', {'type2_en_033', 'complications_en_412'}),
            ('Can uncontrolled diabetes harm my feet?', 'complications_feet', {'type2_en_034', 'complications_en_413'}),
        ]
        assistant = Assistant(CorpusRetriever(), unavailable, KB)
        with patch('assistant_engine.LOGGER'):
            for question, intent, expected in cases:
                with self.subTest(question=question):
                    self.assertEqual(detect_intent(question), intent)
                    ranked = rank_candidates(question, intent, CorpusRetriever()(question, TOPICS[intent][0]))
                    self.assertIn(ranked[0]['id'], expected)
                    result = assistant.answer(question)
                    self.assertEqual(result['response_mode'], 'evidence_fallback')
                    self.assertTrue(set(result['evidence_ids']) <= expected)


if __name__ == '__main__':
    unittest.main()
