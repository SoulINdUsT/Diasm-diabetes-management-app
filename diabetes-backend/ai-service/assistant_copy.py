"""NEW copy: ALL safety text and translations below REQUIRE CLINICAL REVIEW.

This is a conservative software safety boundary, not clinically validated advice.
The low-glucose quantities/timing already occur in exercise_en_008. No new
diagnostic thresholds or individual treatment targets are introduced.
"""

COPY = {
    'emergency_unconscious': (
        'Seek emergency medical help now. Do not give food or drink by mouth to someone who is unconscious or unresponsive. Do not wait for this chat to assess them.',
        'এখনই জরুরি চিকিৎসা সহায়তা নিন। অচেতন বা সাড়া দিচ্ছেন না এমন ব্যক্তিকে মুখে খাবার বা পানীয় দেবেন না। এই চ্যাটের মূল্যায়নের জন্য অপেক্ষা করবেন না.'),
    'emergency_swallowing': (
        'Seek urgent medical help now. Do not give food or drink by mouth to someone who cannot swallow. Do not wait for this chat to assess them.',
        'এখনই জরুরি চিকিৎসা সহায়তা নিন। গিলতে পারছেন না এমন ব্যক্তিকে মুখে খাবার বা পানীয় দেবেন না। এই চ্যাটের জন্য অপেক্ষা করবেন না।'),
    'emergency_breathing': (
        'Seek emergency medical help now for the breathing difficulty you describe. Do not wait for this chat or try to manage it with food or relaxation exercises.',
        'আপনার বর্ণিত শ্বাসকষ্টের জন্য এখনই জরুরি চিকিৎসা সহায়তা নিন। এই চ্যাটের জন্য অপেক্ষা করবেন না বা খাবার কিংবা শিথিলায়নের ব্যায়াম দিয়ে এটি সামলানোর চেষ্টা করবেন না।'),
    'emergency_chest_pain': (
        'Seek emergency medical help now for the chest pain you describe. This chat cannot assess its cause. Do not wait for a diabetes explanation here.',
        'আপনার বর্ণিত বুকে ব্যথার জন্য এখনই জরুরি চিকিৎসা সহায়তা নিন। এই চ্যাটে এর কারণ নির্ণয় করা যায় না। এখানে ডায়াবেটিসের ব্যাখ্যার জন্য অপেক্ষা করবেন না।'),
    'severe_high_glucose': (
        'Very high blood sugar or severe symptoms need urgent medical assessment. Seek urgent medical help now. I cannot recommend an extra insulin dose. Share your glucose reading, its units, symptoms, and prescribed medicines with the healthcare professional.',
        'রক্তে শর্করা খুব বেশি বা উপসর্গ গুরুতর হলে জরুরি চিকিৎসা মূল্যায়ন দরকার। এখনই জরুরি চিকিৎসা সহায়তা নিন। আমি অতিরিক্ত ইনসুলিনের ডোজ বলতে পারি না। চিকিৎসককে শর্করার মাপ, একক, উপসর্গ এবং নির্ধারিত ওষুধের তথ্য জানান।'),
    'pregnancy_concern': (
        'Contact your pregnancy or diabetes care team about this concern. Blood sugar needs careful monitoring during pregnancy. This chat cannot set your treatment target or insulin dose. If symptoms are severe, seek urgent medical help.',
        'এই উদ্বেগ নিয়ে আপনার গর্ভকালীন বা ডায়াবেটিসের চিকিৎসা দলের সঙ্গে যোগাযোগ করুন। গর্ভাবস্থায় রক্তে শর্করা সতর্কভাবে পর্যবেক্ষণ করা দরকার। এই চ্যাট আপনার চিকিৎসার লক্ষ্য বা ইনসুলিনের ডোজ নির্ধারণ করতে পারে না। উপসর্গ গুরুতর হলে জরুরি চিকিৎসা সহায়তা নিন।'),
    'insulin_dose_request': (
        'I cannot calculate, recommend, increase, or double your insulin dose. Use your prescribed instructions and contact the clinician who manages your insulin for dosing guidance. If you feel seriously unwell, seek urgent medical help.',
        'আমি আপনার ইনসুলিনের ডোজ গণনা, সুপারিশ, বাড়ানো বা দ্বিগুণ করার নির্দেশ দিতে পারি না। আপনার নির্ধারিত নির্দেশনা অনুসরণ করুন এবং ডোজের পরামর্শের জন্য ইনসুলিনের চিকিৎসকের সঙ্গে যোগাযোগ করুন। গুরুতর অসুস্থ লাগলে জরুরি চিকিৎসা সহায়তা নিন।'),
    'low_glucose_actions': (
        'If the person is unconscious or cannot swallow, seek emergency medical help and do not give anything by mouth. If awake and able to swallow, stop activity and take 15 grams of fast-acting carbohydrate such as glucose tablets or juice. Wait 15 minutes and recheck blood sugar if possible. If sugar remains low or symptoms continue, repeat the fast-acting carbohydrate. Do not resume exercise until symptoms improve and blood sugar is safer. Seek urgent medical help for severe symptoms.',
        'ব্যক্তি অচেতন হলে বা গিলতে না পারলে জরুরি চিকিৎসা সহায়তা নিন এবং মুখে কিছু দেবেন না। সচেতন ও গিলতে সক্ষম হলে কাজ বা ব্যায়াম থামিয়ে ১৫ গ্রাম দ্রুত শোষিত কার্বোহাইড্রেট, যেমন গ্লুকোজ ট্যাবলেট বা জুস নিন। ১৫ মিনিট অপেক্ষা করে সম্ভব হলে শর্করা আবার মাপুন। শর্করা কম থাকলে বা উপসর্গ চলতে থাকলে দ্রুত শোষিত কার্বোহাইড্রেট আবার নিন। উপসর্গ না কমা ও শর্করা নিরাপদ না হওয়া পর্যন্ত ব্যায়াম শুরু করবেন না। গুরুতর উপসর্গ হলে জরুরি চিকিৎসা সহায়তা নিন।'),
    'insulin_use_safety': (
        'Different insulin types work at different speeds, and low blood sugar is an important side effect. For how and when to use your insulin, follow your prescribed instructions and ask your diabetes clinician or pharmacist to explain the technique. I cannot choose or change your dose.',
        'বিভিন্ন ধরনের ইনসুলিন ভিন্ন গতিতে কাজ করে এবং রক্তে শর্করা কমে যাওয়া একটি গুরুত্বপূর্ণ পার্শ্বপ্রতিক্রিয়া। কীভাবে ও কখন ইনসুলিন ব্যবহার করবেন, সে জন্য আপনার নির্ধারিত নির্দেশনা অনুসরণ করুন এবং চিকিৎসক বা ফার্মাসিস্টের কাছে ব্যবহারের পদ্ধতি বুঝে নিন। আমি আপনার ডোজ বেছে নিতে বা পরিবর্তন করতে পারি না।'),
    'high_glucose_actions': (
        'What is your blood sugar reading, what units does the meter use, and what symptoms are you having? Severe blood sugar problems need quick medical care. If you have severe symptoms, seek urgent medical help. I cannot safely suggest an insulin adjustment from this question.',
        'আপনার রক্তে শর্করার মাপ কত, মিটারে কোন একক ব্যবহার হচ্ছে এবং কী উপসর্গ হচ্ছে? শর্করার গুরুতর সমস্যায় দ্রুত চিকিৎসা দরকার। গুরুতর উপসর্গ হলে জরুরি চিকিৎসা সহায়তা নিন। শুধু এই প্রশ্ন থেকে ইনসুলিন পরিবর্তনের পরামর্শ দিতে পারি না।'),
    'tiredness_clarification': (
        'How long have you felt tired, and do you have a recent blood sugar reading with units or any other symptoms? Tiredness alone does not let this chat determine the cause. If you also have chest pain, breathing difficulty, fainting, or difficulty staying awake, seek urgent medical help.',
        'কত দিন ধরে ক্লান্ত লাগছে? এককসহ সাম্প্রতিক শর্করার মাপ বা অন্য কোনো উপসর্গ আছে কি? শুধু ক্লান্তি থেকে এই চ্যাটে কারণ নির্ধারণ করা যায় না। সঙ্গে বুকে ব্যথা, শ্বাসকষ্ট, অজ্ঞান হওয়া বা জেগে থাকতে কষ্ট হলে জরুরি চিকিৎসা সহায়তা নিন।'),
    'hba1c_target_clarification': (
        'Do you mean the HbA1c range used for diagnosis, or your own treatment target? I can explain the diagnostic information, but your personal target needs guidance from your diabetes clinician.',
        'আপনি কি রোগ নির্ণয়ের জন্য ব্যবহৃত HbA1c-এর সীমা জানতে চান, নাকি আপনার ব্যক্তিগত চিকিৎসার লক্ষ্য? রোগ নির্ণয়ের তথ্য ব্যাখ্যা করতে পারি, তবে ব্যক্তিগত লক্ষ্য চিকিৎসকের পরামর্শে ঠিক করতে হবে।'),
    'care_seeking': (
        'Do you mean routine diabetes follow-up, or an urgent symptom you are having now? If you have chest pain, breathing difficulty, fainting, or difficulty staying awake, seek urgent medical help now rather than waiting for this chat.',
        'আপনি কি ডায়াবেটিসের নিয়মিত ফলো-আপ সম্পর্কে জানতে চান, নাকি এখন কোনো জরুরি উপসর্গ হচ্ছে? বুকে ব্যথা, শ্বাসকষ্ট, অজ্ঞান হওয়া বা জেগে থাকতে কষ্ট হলে এই চ্যাটের জন্য অপেক্ষা না করে এখনই জরুরি চিকিৎসা সহায়তা নিন।'),
    'unknown': (
        'Could you be more specific about the diabetes question or symptoms you want help with? I do not have enough aligned information to answer this safely.',
        'ডায়াবেটিসের কোন প্রশ্ন বা উপসর্গ নিয়ে সহায়তা চান, একটু নির্দিষ্ট করে বলবেন? নিরাপদে উত্তর দেওয়ার মতো প্রাসঙ্গিক তথ্য যথেষ্ট নেই।'),
}

COPY_EVIDENCE = {
    'low_glucose_actions': ['exercise_en_008'],
    'severe_high_glucose': ['type2_en_018'],
    'high_glucose_actions': ['type2_en_018'],
    'pregnancy_concern': ['general_en_005'],
    'insulin_use_safety': ['type2_en_013'],
    'care_seeking': ['type2_en_003', 'type2_en_018'],
}

CLARIFICATIONS = {'high_glucose_actions', 'tiredness_clarification', 'hba1c_target_clarification', 'care_seeking', 'unknown'}

# Focused clarification text, also awaiting wording review.
MISSING_EVIDENCE = {
    'breakfast_suggestions': ('Which breakfast foods would you like to ask about?',
                              'সকালের নাশতার কোন খাবার সম্পর্কে জানতে চান?'),
    'foods_to_limit': ('Which foods are you asking about limiting?',
                       'কোন খাবার সীমিত করা সম্পর্কে জানতে চান?'),
    'glucose_management': ('Are you asking about everyday blood sugar management, or a recent high or low reading? I need a more specific question to find suitable evidence.',
                           'আপনি কি প্রতিদিনের শর্করা নিয়ন্ত্রণ সম্পর্কে জানতে চান, নাকি সাম্প্রতিক বেশি বা কম মাপ সম্পর্কে? উপযুক্ত তথ্যের জন্য প্রশ্নটি একটু নির্দিষ্ট করুন।'),
    'care_seeking': ('What symptoms or concern are making you consider medical care?',
                    'কোন উপসর্গ বা উদ্বেগের জন্য চিকিৎসা নেওয়ার কথা ভাবছেন?'),
}
