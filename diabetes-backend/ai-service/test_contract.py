"""In-process HTTP and adapter checks; all model/network calls are mocked."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

AVAILABLE = all(importlib.util.find_spec(m) for m in ['fastapi', 'httpx', 'requests'])
if AVAILABLE:
    import main
    from fastapi.testclient import TestClient
    from test_regression import CASES, CorpusRetriever, unavailable


@unittest.skipUnless(AVAILABLE, 'Run with the project .venv for FastAPI adapter checks')
class ContractTests(unittest.TestCase):
    def test_http_twelve_and_validation(self):
        with patch.object(main, 'retrieve_candidates', CorpusRetriever()), patch.object(main, 'rewrite_with_ollama', unavailable):
            with TestClient(main.app) as client:
                for case in CASES:
                    result = client.post('/ask', json={'question': case['question'], 'language': 'en'})
                    self.assertEqual(result.status_code, 200)
                    self.assertEqual(result.json()['intent'], case['intent'])
                for payload in [{'question': '  '}, {'question': 'hello', 'language': 'xx'}, {'question': 'x' * 4001}]:
                    self.assertEqual(client.post('/ask', json=payload).status_code, 422)
                self.assertFalse(client.get('/health').json()['retrieval_initialized'])

    def test_chroma_language_and_distance_adapter(self):
        model, collection = Mock(), Mock()
        model.encode.return_value.tolist.return_value = [[0.0]]
        collection.query.return_value = {'ids': [['test']], 'documents': [['text']],
                                         'metadatas': [[{'category': 'type2', 'language': 'en'}]], 'distances': [[0.7]]}
        with patch.object(main, 'retrieval_dependencies', return_value=(model, collection)):
            rows = main.retrieve_candidates('normalized question', ['type2'])
            self.assertEqual(rows[0]['distance'], 0.7)
            self.assertEqual(collection.query.call_args.kwargs['where']['$and'][0], {'language': 'en'})
            self.assertEqual(collection.query.call_args.kwargs['n_results'], 15)
            main.retrieve_candidates('expanded', [])
            self.assertEqual(collection.query.call_args.kwargs['where'], {'language': 'en'})

    def test_ollama_payload_and_timeout(self):
        response = Mock()
        response.json.return_value = {'response': json.dumps({'answerable': True, 'answer': 'Evidence.', 'evidence_ids': ['x']})}
        with patch('requests.post', return_value=response) as post:
            main.rewrite_with_ollama(question='original', normalized_question='rewritten', language='bn',
                                     evidence=[{'id': 'x', 'text': 'Evidence.'}], intent='test', safety_constraints='no dosing')
            args = post.call_args.kwargs
            self.assertEqual(args['json']['model'], 'llama3.1:8b')
            self.assertEqual(args['timeout'], (2, 6))
            for value in ['original', 'rewritten', 'bn', 'no dosing', 'Evidence.']:
                self.assertIn(value, args['json']['prompt'])
            response.raise_for_status.assert_called_once()


class EvaluationTests(unittest.TestCase):
    def test_evaluation_rejects_internal_answer_text(self):
        from evaluate import assess_result
        result = dict(intent='breakfast_suggestions', answer='generation_unavailable: breakfast.',
                      evidence_ids=[], retrieved_ids=[], response_mode='evidence_fallback')
        self.assertIn('internal_terminology', assess_result({'intent': 'breakfast_suggestions'}, result)['failures'])

    def test_keyword_stuffing_never_passes(self):
        from evaluate import keyword_match_score
        score = keyword_match_score('Do not use a1c, fasting or random glucose tests.', ['a1c', 'fasting', 'random glucose'])
        self.assertEqual(score['label'], 'REVIEW_REQUIRED')

    def test_gold_categories_and_avoidance(self):
        root = Path(__file__).resolve().parent
        kb = {r['id']: r for r in json.loads((root.parent / 'ai-data/knowledge_base.json').read_text(encoding='utf-8'))}
        items = json.loads((root / 'evaluation_questions.json').read_text(encoding='utf-8'))
        for item in items:
            self.assertEqual(set(item['expected_categories']), {kb[i]['category'] for i in item['expected_chunk_ids']})
        self.assertIn('nutrition_en_102', items[44]['expected_chunk_ids'])


if __name__ == '__main__':
    unittest.main()
