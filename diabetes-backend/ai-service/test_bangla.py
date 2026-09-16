"""Bangla routing, source translations and real /ask contract regressions."""
import unittest
import unicodedata
from unittest.mock import patch

from fastapi.testclient import TestClient
import main
from assistant_bangla import TRANSLATIONS, translate_evidence
from assistant_engine import Assistant, build_clean_answer, contains_internal_terminology
from assistant_policy import detect_intent, normalize_text, response_language, safety_decision
from test_regression import KB, CorpusRetriever, unavailable

CASES = [
    ('ডায়াবেটিস নিয়ন্ত্রণে সকালের নাস্তায় কী খেতে পারি?', 'breakfast_suggestions', 'nutrition_en_301'),
    ('সকালের নাশতায় কী খাব?', 'breakfast_suggestions', 'nutrition_en_301'),
    ('ডায়াবেটিস কীভাবে নিয়ন্ত্রণ করব?', 'glucose_management', 'type2_en_008'),
    ('আমার blood sugar কীভাবে control করব?', 'glucose_management', 'type2_en_008'),
    ('HbA1c কী?', 'hba1c_definition', 'type2_en_019'),
    ('এইচবিএ১সি পরীক্ষা কী?', 'hba1c_definition', 'type2_en_019'),
    ('HbA1c এর লক্ষ্য কত?', 'hba1c_target_clarification', None),
    ('আমার খুব ক্লান্ত লাগছে', 'tiredness_clarification', None),
    ('কখন ডাক্তারের কাছে যাব?', 'care_seeking', 'type2_en_003'),
    ('আমার রক্তে শর্করা কমে গেছে', 'low_glucose_actions', 'exercise_en_008'),
    ('আমার blood sugar কম', 'low_glucose_actions', 'exercise_en_008'),
    ('ইনসুলিন কত ইউনিট নেব?', 'insulin_dose_request', None),
    ('insulin এর ডোজ বাড়াব কি?', 'insulin_dose_request', None),
    ('ইনসুলিন ব্যবহারের নিয়ম কী?', 'insulin_use_safety', 'type2_en_013'),
    ('ডায়াবেটিসে পায়ের ক্ষত কেন ঝুঁকিপূর্ণ?', 'complications_feet', 'type2_en_034'),
    ('আমার বুকে ব্যথা হচ্ছে', 'emergency_chest_pain', None),
    ('সে অচেতন এবং সুগার কম', 'emergency_unconscious', None),
    ('আমি গিলতে পারছি না, সুগার কম', 'emergency_swallowing', None),
    ('আমার শ্বাসকষ্ট হচ্ছে', 'emergency_breathing', None),
    ('আমার মন খারাপ', 'mental_health_depression_hopelessness', 'mental_en_006'),
    ('বাংলাদেশের রাজধানী কোথায়?', 'unknown', None),
]


class BanglaTests(unittest.TestCase):
    def test_representative_questions_through_post_ask_with_wrong_client_language(self):
        with patch.object(main, 'retrieve_candidates', CorpusRetriever()), patch.object(main, 'rewrite_with_ollama', unavailable), patch('assistant_engine.LOGGER'):
            client = TestClient(main.app)
            for language in ['en', 'bn', None]:
                for question, intent, source in CASES:
                    with self.subTest(question=question, language=language):
                        response = client.post('/ask', json={'question': question, 'language': language})
                        self.assertEqual(response.status_code, 200)
                        result = response.json()
                        self.assertEqual(result['intent'], intent)
                        self.assertEqual(result['language'], 'bn')
                        self.assertEqual(result['knowledge_language'], 'en')
                        self.assertRegex(result['answer'], '[\u0980-\u09ff]')
                        self.assertFalse(contains_internal_terminology(result['answer']))
                        if source:
                            self.assertIn(source, result['evidence_ids'])
                        if intent in ['breakfast_suggestions', 'glucose_management', 'hba1c_definition', 'complications_feet', 'mental_health_depression_hopelessness']:
                            self.assertTrue(result['retrieval_performed'])
                            self.assertEqual(result['response_mode'], 'evidence_fallback')
                            self.assertTrue(result['clinical_review_required'])
                        else:
                            self.assertFalse(result['retrieval_performed'])

    def test_safety_never_calls_models_and_preserves_no_oral_treatment(self):
        def forbidden(*args, **kwargs):
            self.fail('Safety must bypass retrieval and generation')
        assistant = Assistant(forbidden, forbidden, KB)
        for question, intent, _ in CASES:
            if safety_decision(question):
                result = assistant.answer(question, 'en')
                self.assertEqual(result['response_mode'], 'safety')
                self.assertEqual(result['language'], 'bn')
                if intent in ['emergency_unconscious', 'emergency_swallowing']:
                    self.assertNotRegex(result['answer'], r'15|১৫')
                    self.assertIn('দেবেন না', result['answer'])
                if intent == 'insulin_dose_request':
                    self.assertNotRegex(result['answer'], r'\d')
        self.assertIsNone(safety_decision('আমার বুকে ব্যথা নেই'))
        self.assertIsNone(safety_decision('সে অচেতন নয়'))
        self.assertEqual(safety_decision('আমার বুকে ব্যথা নেই কিন্তু শ্বাস নিতে পারছি না'), 'emergency_breathing')

    def test_unicode_variants_and_english_language_selection(self):
        for question, intent, _ in CASES:
            for form in ['NFC', 'NFD']:
                self.assertEqual(detect_intent(unicodedata.normalize(form, question)), intent)
        self.assertEqual(response_language('breakfast', 'en'), 'en')
        self.assertEqual(response_language('breakfast', 'bn'), 'bn')
        self.assertEqual(response_language('breakfast কী খাব', 'en'), 'bn')

    def test_bound_translations_reject_lossy_or_english_generation(self):
        for question in [CASES[0][0], CASES[2][0], CASES[4][0], CASES[14][0], CASES[19][0]]:
            with self.subTest(question=question):
                def lossy(**payload):
                    return dict(answerable=True, answer='খাবার খান।', evidence_ids=[r['id'] for r in payload['evidence']])
                def faithful(**payload):
                    return dict(answerable=True, answer=build_clean_answer([{'document':r['text']} for r in payload['evidence']]), evidence_ids=[r['id'] for r in payload['evidence']])
                a=Assistant(CorpusRetriever(), lossy, KB).answer(question, 'en')
                b=Assistant(CorpusRetriever(), faithful, KB).answer(question, 'en')
                self.assertEqual(a['answer'], b['answer'])
                self.assertEqual(a['response_mode'], 'evidence_fallback')
                self.assertEqual(b['response_mode'], 'generated')
                self.assertEqual(b['language'], 'bn')
        for source, (english, bangla) in TRANSLATIONS.items():
            row={'id':source,'document':english}
            self.assertEqual(translate_evidence([row])[0]['document'], bangla)
            self.assertIsNone(translate_evidence([{**row,'document':english+' Changed.'}]))

    def test_unknown_bangla_is_a_bangla_clarification(self):
        result=Assistant(CorpusRetriever(), unavailable, KB).answer(CASES[-1][0], 'en')
        self.assertEqual(result['response_mode'], 'clarification')
        self.assertIn('নির্দিষ্ট',result['answer'])
        self.assertEqual(result['language'],'bn')


if __name__ == '__main__':
    unittest.main()
