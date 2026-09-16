"""Source-bound Bangla translations; clinical/translation review is still required.

These are display translations, not new KB records or embeddings. Each translation
is accepted only for the exact prepared English passage below. Changed or missing
source text cannot silently reuse a stale translation.
"""
from assistant_copy import COPY


TRANSLATIONS = {
    'nutrition_en_301': (
        'For breakfast in diabetes, a good option is 2 ruti with egg and vegetables or small portion of khichuri with dal. Avoid sugary tea, biscuits, and fruit juice. Adding protein helps prevent blood sugar spikes.',
        'ডায়াবেটিসে সকালের নাস্তায় ডিম ও সবজির সঙ্গে ২টি রুটি অথবা ডাল দিয়ে অল্প পরিমাণ খিচুড়ি একটি ভালো বিকল্প। চিনি দেওয়া চা, বিস্কুট ও ফলের রস এড়িয়ে চলুন। খাবারে প্রোটিন যোগ করলে রক্তে শর্করা হঠাৎ বেড়ে যাওয়া প্রতিরোধে সাহায্য হয়।'),
    'type2_en_008': (
        'Type 2 diabetes is managed through healthy eating, regular exercise, weight control, blood sugar monitoring and medicine or insulin when needed. Diabetes education is also an important part of care.',
        'স্বাস্থ্যকর খাবার, নিয়মিত ব্যায়াম, ওজন নিয়ন্ত্রণ, রক্তে শর্করা পর্যবেক্ষণ এবং প্রয়োজন হলে ওষুধ বা ইনসুলিনের মাধ্যমে টাইপ ২ ডায়াবেটিস নিয়ন্ত্রণ করা হয়। ডায়াবেটিস সম্পর্কে শেখাও যত্নের একটি গুরুত্বপূর্ণ অংশ।'),
    'type2_en_019': (
        'The A1C test is a blood test that shows average blood sugar over the past two to three months.',
        'HbA1c বা A1C হলো একটি রক্ত পরীক্ষা, যা গত দুই থেকে তিন মাসের রক্তে শর্করার গড় মাত্রা দেখায়।'),
    'type2_en_016': (
        'Daily self-care in type 2 diabetes includes following the treatment plan, checking the feet, getting regular eye and dental exams, staying active, eating well, managing blood pressure and cholesterol, avoiding tobacco and getting enough sleep.',
        'টাইপ ২ ডায়াবেটিসে প্রতিদিনের যত্নের মধ্যে রয়েছে চিকিৎসার পরিকল্পনা মেনে চলা, পা পরীক্ষা করা, নিয়মিত চোখ ও দাঁত পরীক্ষা করানো, সক্রিয় থাকা, স্বাস্থ্যকর খাবার খাওয়া, রক্তচাপ ও কোলেস্টেরল নিয়ন্ত্রণে রাখা, তামাক এড়ানো এবং পর্যাপ্ত ঘুমানো।'),
    'type2_en_034': (
        'Diabetic foot problems develop when poor circulation slows healing and reduced protective sensation allows small injuries to be missed. This can lead to ulcers, infections, and in severe cases amputation. Daily foot checks, proper footwear, and good blood sugar control help reduce the risk.',
        'ডায়াবেটিসে রক্তসঞ্চালন কমে গেলে পায়ের ক্ষত শুকাতে দেরি হয় এবং অনুভূতি কমে যাওয়ায় ছোট আঘাত নজরে না-ও আসতে পারে। এর ফলে ঘা, সংক্রমণ এবং গুরুতর ক্ষেত্রে অঙ্গচ্ছেদের প্রয়োজন হতে পারে। প্রতিদিন পা পরীক্ষা করা, উপযুক্ত জুতা পরা এবং রক্তে শর্করা ভালোভাবে নিয়ন্ত্রণে রাখা ঝুঁকি কমাতে সাহায্য করে।'),
    'complications_en_413': (
        'Diabetes causes foot problems by reducing blood flow and damaging nerves. This can lead to unnoticed injuries, infections, ulcers and in severe cases, amputation.',
        'ডায়াবেটিসে রক্তপ্রবাহ কমে যাওয়া ও স্নায়ুর ক্ষতির কারণে পায়ে সমস্যা হয়। এতে আঘাত নজরে না-ও আসতে পারে, সংক্রমণ ও ঘা হতে পারে এবং গুরুতর ক্ষেত্রে অঙ্গচ্ছেদের প্রয়োজন হতে পারে।'),
    'mental_en_006': (
        'When you feel depressed with diabetes, do not try to fix the whole day at once. Start with one small action such as drinking water, taking 10 slow breaths, eating a simple meal, checking blood sugar, or taking a short walk. If low mood keeps affecting sleep, food, medicine, or daily function, get professional help. If there is any risk of harming yourself or others, seek emergency help immediately.',
        'ডায়াবেটিসের সঙ্গে বিষণ্ণ লাগলে একসঙ্গে পুরো দিনের সবকিছু ঠিক করার চেষ্টা করবেন না। পানি পান করা, ১০ বার ধীরে শ্বাস নেওয়া, সাধারণ খাবার খাওয়া, রক্তে শর্করা মাপা বা অল্প হাঁটার মতো একটি ছোট কাজ দিয়ে শুরু করুন। মন খারাপের কারণে ঘুম, খাওয়া, ওষুধ নেওয়া বা দৈনন্দিন কাজ ব্যাহত হতে থাকলে পেশাদার সহায়তা নিন। নিজের বা অন্যের ক্ষতি করার কোনো ঝুঁকি থাকলে অবিলম্বে জরুরি সহায়তা নিন।'),
}


def translate_evidence(evidence):
    """Return a complete bound translation or None, never a partial safety answer."""
    translated = []
    for row in evidence:
        pair = TRANSLATIONS.get(row['id'])
        if row['id'] == 'exercise_en_008':
            pair = COPY['low_glucose_actions']
        if not pair or row['document'].strip() != pair[0]:
            return None
        translated.append({**row, 'document': pair[1], 'document_language': 'bn',
                           'preserve_text': True,
                           'translation_source': 'assistant_bangla-v1-unreviewed'})
    return translated or None
