"""Pure routing policy. New safety/clarification copy requires clinical review.

No medical thresholds are inferred here. Numeric readings need units/context and
are not used to diagnose. Alias matching uses whole normalized phrases.
"""
import re
import unicodedata


def contains(text, phrases):
    return any(re.search(r'(?<!\S)' + re.escape(p) + r'(?!\S)', text) for p in phrases)


ALIASES = {
    'glycated haemoglobin': 'hba1c', 'glycated hemoglobin': 'hba1c',
    'hb a1c': 'hba1c', 'hb1ac': 'hba1c', 'a1c': 'hba1c',
    'সুগার কমে গেছে': 'low glucose', 'রক্তে শর্করা বেশি': 'high glucose',
    'কখন ডাক্তার দেখাব': 'when should i contact doctor',
    'খেতে পারছে না': 'cannot swallow', 'গিলতে পারছি না': 'cannot swallow',
    'শ্বাস নিতে পারছি না': 'cannot breathe', 'শ্বাসকষ্ট': 'breathing difficulty',
    'বুকে ব্যথা': 'chest pain', 'অচেতন': 'unconscious', 'অজ্ঞান': 'unconscious',
    'গর্ভবতী': 'pregnant', 'ইনসুলিন': 'insulin', 'ডোজ': 'dose', 'ইউনিট': 'units', 'ডায়াবেটিস': 'diabetes',
    'সকালের নাশতা': 'breakfast', 'সকালে কি খাব': 'breakfast',
    'হাইপোগ্লাইসেমিয়া': 'low glucose', 'হাইপারগ্লাইসেমিয়া': 'high glucose',
    'রক্তে শর্করা': 'glucose', 'রক্তের শর্করা': 'glucose', 'সুগার': 'glucose',
    'শর্করা': 'glucose', 'গ্লুকোজ': 'glucose', 'বেশি': 'high', 'কম': 'low',
    'ডাক্তার': 'doctor', 'চিকিৎসক': 'doctor', 'হাসপাতাল': 'hospital', 'জরুরি': 'emergency',
    'ki korbo': 'what should i do', 'কি করব': 'what should i do',
    'amar': 'my', 'beshi': 'high', 'kom': 'low',
    'blood glucose': 'glucose', 'blood sugar': 'glucose', 'sugar': 'glucose',
    'hypoglycaemia': 'low glucose', 'hypoglycemia': 'low glucose',
    'hyperglycaemia': 'high glucose', 'hyperglycemia': 'high glucose',
    'physician': 'doctor', 'doctors': 'doctor', 'physicians': 'doctor',
    'can t': 'cannot', 'can not': 'cannot', 'don t': 'do not', 'doesn t': 'does not',
    'extremely high': 'very high', 'too high': 'very high',
    'chest hurts': 'chest pain',
}


def normalize_text(text):
    text = unicodedata.normalize('NFC', (text or '').casefold())
    # Python \w excludes combining vowel signs; Unicode categories preserve them.
    text = ''.join(c if unicodedata.category(c)[0] in 'LNM' else ' ' for c in text)
    text = ' '.join(text.split())
    for source, target in sorted(ALIASES.items(), key=lambda pair: -len(pair[0])):
        text = re.sub(r'(?<!\S)' + re.escape(source) + r'(?!\S)', target, text)
    text = re.sub(r'\bglucose(?: level)?(?: is| gets?| got| has become)? (very |severely |dangerously )?(high|low)\b',
                  lambda m: (m[1] or '') + m[2] + ' glucose', text)
    text = re.sub(r'\bglucose (?:drops?|dropped|dropping)\b', 'low glucose', text)
    return ' '.join(text.split())


def educational(q):
    introductory = bool(re.match(r'^(what (?:is|are|does|if|causes)|how does|explain|define|why (?:does|is)|tell me about|is chest pain|can chest pain)\b', q))
    current = contains(q, ['i have', 'i am', 'i feel', 'i cannot', 'he is', 'she is', 'my glucose', 'right now'])
    return introductory and not current


def asserted(q, phrases):
    for phrase in phrases:
        for match in re.finditer(r'(?<!\S)' + re.escape(phrase) + r'(?!\S)', q):
            prefix = re.split(r'\b(?:but|and|however)\b', q[:match.start()])[-1]
            if re.search(r'\b(?:no|not|never|without|denies|deny)\b(?:\s+\w+){0,4}\s*$', prefix):
                continue
            if re.match(r'\s+(?:নেই|নয়|নয়|না)(?:\s|$)', q[match.end():]):
                continue
            return True
    return False


def safety_decision(question):
    q = normalize_text(question)
    if not educational(q):
        for intent, phrases in [
            ('emergency_unconscious', ['unconscious', 'unresponsive', 'passed out', 'seizure']),
            ('emergency_swallowing', ['cannot swallow', 'unable to swallow']),
            ('emergency_breathing', ['breathing difficulty', 'difficulty breathing', 'trouble breathing', 'cannot breathe', 'unable to breathe', 'not breathing', 'shortness of breath']),
            ('emergency_chest_pain', ['chest pain', 'chest pressure']),
        ]:
            if asserted(q, phrases):
                return intent
        if asserted(q, ['very high glucose', 'severely high glucose', 'dangerously high glucose']):
            return 'severe_high_glucose'
        if asserted(q, ['high glucose']) and asserted(q, ['vomiting', 'confused', 'confusion', 'severe weakness', 'ketones']):
            return 'severe_high_glucose'
        if asserted(q, ['low glucose', 'shaky', 'shaking', 'sweating and dizzy']):
            return 'low_glucose_actions'
        if asserted(q, ['pregnant', 'pregnancy', 'gestational']) and contains(q, ['glucose', 'diabetes', 'insulin']):
            return 'pregnancy_concern'
    if contains(q, ['insulin']) and contains(q, ['dose', 'dosing', 'units', 'increase', 'double', 'calculate', 'recommend', 'how much']):
        # Educational dose questions also receive the boundary, not a calculation.
        if asserted(q, ['insulin']):
            return 'insulin_dose_request'
    if not educational(q) and asserted(q, ['low glucose', 'shaky', 'shaking', 'sweating and dizzy']):
        return 'low_glucose_actions'
    return None


def detect_intent(question):
    q = normalize_text(question)
    safety = safety_decision(question)
    if safety:
        return safety
    if contains(q, ['hba1c']):
        if contains(q, ['my target', 'mine', 'my goal', 'my hba1c', 'limit', 'target', 'goal']):
            return 'hba1c_target_clarification'
        if contains(q, ['range', 'diagnostic', 'normal', 'level means diabetes', 'diagnosis']):
            return 'hba1c_diagnostic_range'
        return 'hba1c_definition'
    if contains(q, ['doctor', 'hospital', 'emergency', 'medical help', 'urgent care']):
        return 'care_seeking'
    glucose_explanation = contains(q, ['damage', 'damages', 'affect', 'harm']) and educational(q)
    if asserted(q, ['high glucose']) and not educational(q):
        return 'high_glucose_actions'
    if contains(q, ['low glucose', 'high glucose']) and educational(q) and not glucose_explanation:
        return 'glucose_information'
    if contains(q, ['insulin']) and contains(q, ['usage', 'use', 'using', 'rules', 'take', 'inject', 'injection', 'safe']):
        return 'insulin_use_safety'
    if contains(q, ['breakfast']) and not contains(q, ['lunch', 'dinner', 'full day']):
        return 'breakfast_suggestions'
    if contains(q, ['food', 'foods', 'eat', 'diet']) and contains(q, ['avoid', 'limit', 'restrict']):
        return 'foods_to_limit'
    if contains(q, ['prevent', 'prevention', 'avoid diabetes', 'reduce risk']):
        return 'prevention_info'
    if contains(q, ['hungry', 'hunger', 'appetite']):
        return 'nutrition_hunger_management'
    if contains(q, ['glucose', 'diabetes']) and contains(q, ['manage', 'management', 'control', 'lower', 'reduce']):
        return 'glucose_management'
    if contains(q, ['burnout', 'burned out', 'tired of diabetes', 'tired of managing', 'tired of checking', 'fed up']):
        return 'mental_health_burnout'
    if contains(q, ['tired', 'fatigue', 'tiredness', 'exhausted']):
        return 'tiredness_clarification'
    # Specific nonurgent domains precede broad symptom/nutrition categories.
    rules = [
        ('mental_health_relaxation_tools', ['meditation', 'breathing exercise', 'relaxation', 'grounding', 'yoga', 'stretching']),
        ('mental_health_depression_hopelessness', ['depressed', 'depression', 'hopeless', 'giving up', 'low mood']),
        ('mental_health_support_connection', ['no support', 'support group', 'family support', 'talk to someone']),
        ('mental_health_stress_anxiety', ['stress', 'stressed', 'anxious', 'anxiety', 'worried', 'angry', 'hate']),
        ('complications_eyes', ['eyes', 'eye', 'retina', 'retinopathy', 'blurred vision']),
        ('complications_kidneys', ['kidney', 'kidneys', 'renal', 'protein in urine']),
        ('complications_nerves', ['nerve', 'nerves', 'neuropathy', 'tingling', 'numb', 'numbness']),
        ('complications_heart_vessels', ['heart', 'stroke', 'blood vessel', 'blood vessels', 'cardiovascular']),
        ('complications_feet', ['foot', 'feet', 'wound', 'wounds', 'ulcer']),
        ('complications_general', ['complication', 'complications', 'damage the body', 'organs', 'not treated', 'untreated', 'uncontrolled diabetes']),
        ('exercise_safety', ['precaution', 'precautions', 'exercise safety', 'safe before exercise', 'exercise with insulin']),
        ('exercise_guidance', ['exercise', 'walking', 'walk', 'workout', 'steps', 'physical activity', 'after meals']),
        ('lifestyle_selfcare', ['self care', 'daily care', 'daily routine', 'dental care', 'blood pressure']),
        ('symptoms_risk', ['symptoms', 'warning signs', 'thirsty', 'thirst', 'urinate', 'urination', 'family history', 'overweight', 'risk factors']),
        ('diagnosis_tests', ['test', 'tests', 'tested', 'diagnose', 'diagnosis', 'screened', 'screening', 'fasting', 'ogtt']),
        ('meal_plan_request', ['meal plan', 'diet plan', 'full day', 'breakfast lunch dinner']),
        ('nutrition_night_eating', ['night snack', 'at night', 'late night', 'before bed']),
        ('nutrition_eating_out', ['restaurant', 'outside', 'fast food', 'biryani']),
        ('nutrition_hunger_management', ['hungry', 'hunger', 'appetite']),
        ('nutrition_general', ['food', 'foods', 'eat', 'diet', 'rice', 'roti', 'fruit', 'plate', 'snack', 'lunch', 'dinner']),
        ('medication_info', ['medicine', 'medication', 'metformin', 'insulin', 'tablet']),
    ]
    for intent, phrases in rules:
        if contains(q, phrases):
            return intent
    if contains(q, ['diabetes', 'glucose', 'prediabetes']) and contains(q, ['what is', 'what causes', 'why', 'difference', 'cured', 'cure', 'remission']):
        return 'basics_info'
    return 'unknown'


# Topic facets are evidence alignment checks, not medical rules or confidence probabilities.
# tuple: categories, standalone retrieval topic, acceptable focused title phrases
TOPICS = {
    'glucose_management': (['type2', 'lifestyle management'], 'How type 2 diabetes is managed healthy eating exercise glucose monitoring', ['managed', 'self care']),
    'breakfast_suggestions': (['nutrition'], 'What to eat for breakfast in diabetes', ['breakfast']),
    'foods_to_limit': (['nutrition', 'diet'], 'Foods to avoid or strictly limit in diabetes', ['foods to avoid', 'foods to limit']),
    'care_seeking': (['type2'], 'When to see a doctor for diabetes symptoms', ['doctor']),
    'hba1c_definition': (['type2'], 'What is the A1C test average blood sugar', ['hba1c test']),
    'hba1c_diagnostic_range': (['type2'], 'A1C diagnostic range for diabetes', ['hba1c test']),
    'prevention_info': (['prevention'], 'Preventing type 2 diabetes', ['preventing']),
    'glucose_information': (['glucose monitoring', 'lifestyle'], 'High and low blood sugar warning signs', ['high and low glucose', 'low glucose']),
    'basics_info': (['basics', 'type2'], '', []),
    'diagnosis_tests': (['type2'], 'Diabetes diagnosis tests screening', ['test', 'diagnosed', 'screened']),
    'symptoms_risk': (['type2'], 'Diabetes symptoms and risk factors', ['symptoms', 'risk factors']),
    'exercise_guidance': (['exercise', 'lifestyle'], 'Diabetes exercise walking guidance', ['exercise', 'walking']),
    'exercise_safety': (['exercise', 'lifestyle'], 'Exercise safety precautions with diabetes', ['safety', 'precautions', 'before exercise']),
    'nutrition_general': (['nutrition', 'diet'], 'Healthy eating in diabetes plate method', ['healthy eating', 'plate method', 'carbohydrates']),
    'meal_plan_request': (['nutrition'], 'Simple daily meal structure breakfast lunch dinner snacks', ['daily meal structure']),
    'nutrition_night_eating': (['nutrition'], 'Late night eating diabetes snacks', ['late night']),
    'nutrition_eating_out': (['nutrition'], 'Eating outside with diabetes', ['eating outside']),
    'nutrition_hunger_management': (['nutrition'], 'Managing hunger in diabetes', ['hunger']),
    'medication_info': (['medication awareness'], 'Medicines for type 2 diabetes', []),
    'lifestyle_selfcare': (['lifestyle management'], 'Daily self care for type 2 diabetes', ['self care']),
}
for suffix, phrases in {
    'eyes': ['eye', 'eyes', 'retinopathy'], 'kidneys': ['kidney', 'nephropathy'],
    'nerves': ['nerve', 'neuropathy'], 'heart_vessels': ['heart', 'cardiovascular'],
    'feet': ['foot', 'feet'], 'general': ['complications', 'damages the body', 'not treated'],
}.items():
    TOPICS['complications_' + suffix] = (['complications', 'type2'], 'Diabetes ' + ' '.join(phrases), phrases)
for suffix, phrases in {
    'stress_anxiety': ['stress', 'anxiety', 'angry', 'hating'], 'burnout': ['burnout', 'burned out', 'tired'],
    'depression_hopelessness': ['depression', 'depressed', 'giving up'],
    'support_connection': ['social support'], 'relaxation_tools': ['meditation', 'breathing', 'yoga', 'grounding'],
}.items():
    TOPICS['mental_health_' + suffix] = (['mental_health', 'mental health'], 'Diabetes ' + ' '.join(phrases), phrases)
