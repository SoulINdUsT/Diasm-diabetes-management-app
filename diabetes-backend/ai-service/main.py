from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
import chromadb
from pathlib import Path
from typing import Optional, List, Dict, Any
import re
import requests

def rewrite_with_ollama(text: str) -> str:
    prompt = f"""
You are a strict medical assistant.

Follow these rules strictly:
- ONLY use the text given below
- DO NOT add any extra information
- DO NOT explain beyond the text
- DO NOT mention studies or external knowledge
- Keep the meaning exactly the same
- Just rewrite it in simple, clear words

Text:
{text}

Final Answer:
"""

    try:
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "llama3.1:8b",
                "prompt": prompt,
                "stream": False
            }
        )
        return response.json()["response"].strip()
    except:
        return text  # fallback (very important)
app = FastAPI()


class QueryRequest(BaseModel):
    question: str
    language: Optional[str] = None


model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

db_path = Path(__file__).resolve().parent / "chroma_db"
client = chromadb.PersistentClient(path=str(db_path))


INTENT_DB_CATEGORY_MAP = {
    "basics_info": ["basics"],

    "diagnosis_tests": ["type2"],
    "symptoms_risk": ["type2"],

    "complications_general": ["complications", "type2"],
    "complications_eyes": ["complications", "type2"],
    "complications_kidneys": ["complications", "type2"],
    "complications_nerves": ["complications", "type2"],
    "complications_heart_vessels": ["complications", "type2"],
    "complications_feet": ["complications", "type2"],

    "exercise_guidance": ["exercise", "lifestyle"],
    "exercise_safety": ["exercise", "lifestyle"],

    "nutrition_general": ["nutrition", "diet"],
    "nutrition_high_sugar": ["nutrition"],
    "meal_plan_request": ["nutrition"],
    "nutrition_night_eating": ["nutrition"],
    "nutrition_eating_out": ["nutrition"],
    "nutrition_hunger_management": ["nutrition"],

    "mental_health_stress_anxiety": ["mental_health", "mental health"],
    "mental_health_burnout": ["mental_health", "mental health"],
    "mental_health_depression_hopelessness": ["mental_health", "mental health"],
    "mental_health_support_connection": ["mental_health", "mental health"],
    "mental_health_relaxation_tools": ["mental_health", "mental health"],

    "glucose_high_low": ["glucose monitoring", "lifestyle"],
    "medication_info": ["medication awareness"],
    "prevention_info": ["prevention"],
    "lifestyle_selfcare": ["lifestyle management"],
}


def normalize_text(text: str) -> str:
    text = (text or "").lower().strip()
    text = re.sub(r"[^\w\s]", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text


def has_any(text: str, keywords: List[str]) -> bool:
    return any(keyword in text for keyword in keywords)


def detect_intent(question: str) -> str:
    q = normalize_text(question)

    def any_term(terms: List[str]) -> bool:
        return any(term in q for term in terms)

    # Low/high sugar first, because these are safety-related.
    if any_term([
        "low sugar", "low blood sugar", "hypoglycemia", "sugar drops", "sugar drop",
        "sugar dropped", "sugar is low", "glucose is low", "shaky", "shaking",
        "sweating", "sweat", "dizzy", "weak", "faint", "confused",
        "fast acting carbohydrate"
    ]):
        return "glucose_high_low"

    if any_term([
        "high sugar", "high blood sugar", "hyperglycemia", "sugar is high",
        "blood sugar is high", "glucose is high", "sugar level high"
    ]):
        if any_term(["eat", "food", "meal", "diet", "drink"]):
            return "nutrition_high_sugar"
        return "glucose_high_low"

    # Mental health.
    if any_term([
        "hate this disease", "hate this illness", "angry", "frustrated",
        "stress", "stressed", "anxious", "anxiety", "worried", "worry",
        "panic", "overwhelmed", "mental pressure", "mentally overwhelmed"
    ]):
        return "mental_health_stress_anxiety"

    if any_term([
        "burnout", "burned out", "tired of diabetes", "tired of managing",
        "tired of checking", "fed up", "exhausted", "diabetes feels exhausting",
        "done with diabetes", "tired of dealing"
    ]):
        return "mental_health_burnout"

    if any_term([
        "depressed", "depression", "hopeless", "sad", "low mood",
        "feel like giving up", "giving up", "cannot do this anymore",
        "can t do this anymore", "dont feel like doing anything",
        "do not feel like doing anything"
    ]):
        return "mental_health_depression_hopelessness"

    if any_term([
        "no support", "support group", "family support", "friends support",
        "talk to someone", "who can support me", "who can help me"
    ]):
        return "mental_health_support_connection"

    if any_term([
        "meditation", "breathing", "breathing exercise", "relaxation",
        "grounding", "calm me down", "yoga", "stretching"
    ]):
        return "mental_health_relaxation_tools"

    # Diagnosis / symptoms / risk.
    if any_term([
        "a1c", "hba1c", "fasting blood sugar", "fasting glucose",
        "random blood sugar", "random glucose", "ogtt", "oral glucose tolerance",
        "diagnose", "diagnosis", "test", "tested", "screened", "screening",
        "confirm diabetes", "blood tests"
    ]):
        return "diagnosis_tests"

    if any_term([
        "symptom", "symptoms", "warning sign", "warning signs", "early signs",
        "thirsty", "thirst", "urinate", "urination", "frequent urination",
        "fatigue", "tired", "blurred vision", "weight loss", "slow healing",
        "infection", "am i high risk", "high risk", "risk factor", "family history",
        "overweight", "obesity", "pcos"
    ]):
        return "symptoms_risk"

    # Complications.
    if any_term(["eye", "eyes", "retina", "retinopathy", "vision", "blurred vision", "floaters"]):
        return "complications_eyes"

    if any_term(["kidney", "kidneys", "nephropathy", "protein in urine", "urine protein", "renal"]):
        return "complications_kidneys"

    if any_term(["nerve", "nerves", "neuropathy", "tingling", "numbness", "numb", "burning pain"]):
        return "complications_nerves"

    if any_term(["heart", "heart disease", "stroke", "blood vessel", "blood vessels", "circulation", "cardiovascular"]):
        return "complications_heart_vessels"

    if any_term(["foot", "feet", "ulcer", "wound", "amputation", "shoe", "foot care"]):
        return "complications_feet"

    if any_term([
        "complication", "complications", "organ damage", "damage the body",
        "not treated", "untreated", "long term effect", "long term effects",
        "uncontrolled diabetes"
    ]):
        return "complications_general"

    # Exercise.
    if any_term([
        "safe before exercise", "sugar before exercise",
        "low blood sugar during exercise", "sugar drops during workout",
        "precaution", "precautions", "exercise safety", "exercise with insulin",
        "exercise with complications", "shaky during workout"
    ]):
        return "exercise_safety"

    if any_term([
        "exercise", "workout", "walk", "walking", "steps", "step count",
        "aerobic", "strength training", "physical activity", "activity",
        "sedentary", "sitting", "after meals", "post meal",
        "how much should i walk", "how long should i walk", "how many minutes",
        "best time to exercise", "when should i exercise"
    ]):
        return "exercise_guidance"

    if any_term([
        "self care", "daily care", "daily routine", "eye exam",
        "dental care", "blood pressure", "foot check"
    ]):
        return "lifestyle_selfcare"

    # Nutrition.
    if any_term([
        "meal plan", "diet plan", "full day meal", "full day diet",
        "1200 kcal", "1400 kcal", "1600 kcal", "1800 kcal", "2000 kcal",
        "calorie plan", "breakfast lunch dinner"
    ]):
        return "meal_plan_request"

    if any_term([
        "night snack", "late night", "at night", "before bed",
        "eat at night", "bedtime snack"
    ]):
        return "nutrition_night_eating"

    if any_term([
        "restaurant", "outside food", "eating outside", "eat outside",
        "fast food", "biryani", "restaurant food"
    ]):
        return "nutrition_eating_out"

    if any_term([
        "hungry", "hunger", "appetite", "always hungry",
        "hungry all the time", "control hunger"
    ]):
        return "nutrition_hunger_management"

    if any_term([
        "food", "foods", "eat", "eating", "diet", "diabetic diet",
        "suggest me a diet", "suggest a diet", "what should i eat",
        "what can i eat", "foods to avoid", "healthy eating",
        "rice", "roti", "fruit", "banana", "mango", "vegetables",
        "protein", "carbohydrate", "carbs", "plate method",
        "portion", "portion control", "snack", "lunch", "dinner", "breakfast"
    ]):
        return "nutrition_general"

    # Medication / prevention / basics.
    if any_term([
        "medicine", "medication", "tablet", "metformin", "insulin",
        "injection", "dose", "drug", "glp", "sglt"
    ]):
        return "medication_info"

    if any_term([
        "prevent", "prevention", "avoid diabetes", "stop diabetes",
        "reduce risk", "prediabetes"
    ]):
        return "prevention_info"

    if any_term([
        "what is diabetes", "what is type 2 diabetes", "type 2 diabetes",
        "insulin resistance", "blood sugar", "glucose", "cause", "causes",
        "why diabetes happens", "cure", "cured", "remission"
    ]):
        return "basics_info"

    return "basics_info"


def get_direct_answer(query: str, detected_intent: str, target_categories: List[str], language: str) -> Optional[Dict[str, Any]]:
    q = normalize_text(query)

    def response(answer: str, category: str, ids: List[str]) -> Dict[str, Any]:
        return {
            "answer": answer,
            "category": category,
            "categories": target_categories,
            "language": language or "en",
            "intent": detected_intent,
            "retrieved_ids": ids
        }

    # High-confidence answer templates for common real-user questions.
    if detected_intent == "exercise_guidance" and ("walk" in q or "walking" in q or "steps" in q or "how much" in q or "how long" in q):
        return response(
            "Walking is a good and safe exercise for many people with diabetes. A practical target is about 30 minutes on most days, or at least 150 minutes of moderate aerobic activity per week. If you are a beginner, start with 10 to 15 minutes of walking after meals, 3 to 4 days a week, then increase gradually. Walking after meals is especially helpful because it can reduce blood sugar spikes. Wear comfortable shoes, stay hydrated, and check blood sugar if you use insulin or medicines that can cause low sugar.",
            "lifestyle",
            ["exercise_en_002", "exercise_en_009", "exercise_en_114", "exercise_en_007"]
        )

    if detected_intent == "glucose_high_low" and any(t in q for t in ["low", "drop", "drops", "dropped", "hypoglycemia", "shaky", "dizzy", "sweat"]):
        return response(
            "If your blood sugar drops or you feel symptoms like shaking, sweating, dizziness, hunger, weakness, or confusion, stop activity and take fast-acting carbohydrate. A common first step is 15 grams of fast-acting carbohydrate, such as glucose tablets, fruit juice, or a regular sugary drink. Wait 15 minutes and recheck blood sugar if possible. If symptoms continue or sugar is still low, repeat the fast-acting carbohydrate. Do not exercise or drive until you feel better. Seek urgent medical help if confusion, fainting, seizure, or severe weakness occurs.",
            "glucose monitoring",
            ["type2_en_018", "exercise_en_008"]
        )

    if detected_intent == "symptoms_risk":
        return response(
            "Warning signs of diabetes can include increased thirst, frequent urination, unusual hunger, tiredness, blurred vision, unexplained weight loss, slow-healing sores, frequent infections, and tingling or numbness in the hands or feet. Symptoms can develop slowly, so some people may not notice them at first. If you have these symptoms or risk factors such as overweight, family history, or prediabetes, you should get blood sugar testing from a healthcare professional.",
            "type2",
            ["type2_en_002", "type2_en_003", "type2_en_005", "type2_en_024"]
        )

    if detected_intent == "nutrition_general" and any(t in q for t in ["suggest", "diet", "food", "eat", "plate", "what should i eat", "foods good"]):
        return response(
            "A good diabetes diet should focus on portion control and balanced meals. Use the plate method: half the plate should be non-starchy vegetables, one quarter protein such as fish, chicken, egg, or dal, and one quarter carbohydrate such as rice, roti, oats, or whole grains. Choose vegetables, protein, dal, fish, eggs, whole wheat roti, oats, brown rice, and controlled fruit portions. Limit sugary drinks, sweets, fried foods, bakery items, and large portions of white rice. Do not eat carbohydrate foods alone; pair rice or roti with protein and vegetables.",
            "nutrition",
            ["nutrition_en_103", "nutrition_en_101", "nutrition_en_102", "nutrition_en_104"]
        )

    if detected_intent == "nutrition_high_sugar":
        return response(
            "When blood sugar is high, choose foods that do not raise it further. Drink water, avoid sugary drinks and sweets, and choose low-carbohydrate foods such as non-starchy vegetables with protein like egg, fish, chicken, or dal. Avoid large portions of rice, roti, bread, noodles, fruit juice, and desserts during that time. Light walking may help if you feel well, but if blood sugar is very high, symptoms are severe, or levels stay high, contact a healthcare professional.",
            "nutrition",
            ["nutrition_en_421", "nutrition_en_102", "nutrition_en_103"]
        )

    if detected_intent == "meal_plan_request":
        return response(
            "A simple full-day diabetic meal plan can include: breakfast with 2 whole wheat ruti, egg white or dal, and vegetables; a mid-morning snack such as a small fruit or 10 to 15 g peanuts; lunch with controlled rice, lean fish or chicken, vegetables, and salad; an evening snack such as peanuts, roasted chana, boiled egg, or a small fruit; dinner with 2 ruti or a small rice portion plus protein and vegetables; and optional half cup milk before bed. Portions should be adjusted based on body weight, glucose level, activity, and medical advice.",
            "nutrition",
            ["nutrition_en_201", "nutrition_en_202", "nutrition_en_420"]
        )

    if detected_intent == "nutrition_night_eating":
        return response(
            "At night, keep food light and controlled. Safer options can include half a cup of milk, one boiled egg, or a small handful of peanuts. Avoid rice, sweets, fried foods, sugary drinks, and heavy meals late at night. Try to finish dinner 2 to 3 hours before sleep.",
            "nutrition",
            ["nutrition_en_305", "nutrition_en_304"]
        )

    if detected_intent == "nutrition_eating_out":
        return response(
            "When eating outside with diabetes, choose grilled, boiled, or lightly cooked foods. Good choices include grilled fish or chicken with vegetables, small portions of plain rice with dal and vegetables, or tandoori chicken without extra oil. Avoid fried foods, biryani, sugary drinks, desserts, and large portions. Eat slowly and control portion size.",
            "nutrition",
            ["nutrition_en_306"]
        )

    if detected_intent == "nutrition_hunger_management":
        return response(
            "Frequent hunger in diabetes can happen when meals lack protein or vegetables, when meals are skipped, or when too many carbohydrates are eaten alone. Eat regular meals, include protein in each meal, add vegetables for volume, drink enough water, and choose small snacks such as peanuts, boiled egg, roasted chana, or a small fruit. Avoid sweets and large carbohydrate-only meals.",
            "nutrition",
            ["nutrition_en_307", "nutrition_en_107", "nutrition_en_304"]
        )

    if detected_intent == "diagnosis_tests":
        return response(
            "Diabetes can be diagnosed using blood tests such as A1C, fasting blood sugar, random blood sugar, and oral glucose tolerance test. A1C shows average blood sugar over the past two to three months. Fasting blood sugar is checked after not eating overnight. Random blood sugar can be checked at any time, especially if symptoms are present. An oral glucose tolerance test checks how the body handles sugar after drinking a sugary liquid.",
            "type2",
            ["type2_en_006", "type2_en_019", "type2_en_020", "type2_en_021", "type2_en_022"]
        )

    return None


def get_query_keywords(query: str) -> List[str]:
    stop_words = {
        "what", "is", "are", "the", "of", "a", "an", "how", "does", "do", "can",
        "why", "when", "should", "i", "my", "in", "on", "for", "to", "and", "me"
    }
    words = normalize_text(query).split()
    return [w for w in words if w not in stop_words and len(w) > 2]


def score_candidate(query: str, metadata: Dict[str, Any], document: str) -> int:
    score = 0

    query_norm = normalize_text(query)
    title_norm = normalize_text(metadata.get("title", ""))
    doc_norm = normalize_text(document)
    query_keywords = get_query_keywords(query)

    for kw in query_keywords:
        if kw in title_norm:
            score += 12
        if kw in doc_norm:
            score += 4

    preferred_by_intent = {
        "diagnosis_tests": ["a1c", "fasting", "random", "oral glucose", "diagnosed"],
        "symptoms_risk": ["symptoms", "warning", "thirst", "urination", "risk factors"],
        "exercise_guidance": ["150 minutes", "30 minutes", "walking", "beginner", "after meals"],
        "exercise_safety": ["safety", "low blood sugar", "15 grams", "before exercise"],
        "nutrition_general": ["plate method", "portion", "vegetables", "protein", "carbohydrates"],
        "meal_plan_request": ["breakfast", "lunch", "dinner", "snack", "meal plan"],
        "nutrition_high_sugar": ["high sugar", "avoid sugar", "vegetables", "protein"],
    }

    intent = detect_intent(query)
    for term in preferred_by_intent.get(intent, []):
        if term in title_norm or term in doc_norm:
            score += 35

    if "walking" in query_norm or "walk" in query_norm:
        if "30 minutes" in doc_norm or "150 minutes" in doc_norm:
            score += 80
        if "walking is very good" in doc_norm:
            score += 20

    if "low sugar" in query_norm or "sugar drops" in query_norm or "shaky" in query_norm:
        if "15 grams" in doc_norm or "fast acting carbohydrate" in doc_norm:
            score += 100
        if "high and low blood sugar" in title_norm:
            score += 30

    return score


def rerank_results(query: str, results: Dict[str, Any]) -> List[Dict[str, Any]]:
    docs = results["documents"][0]
    metas = results["metadatas"][0]
    ids = results["ids"][0]

    scored_results = []
    for idx, (doc, meta, doc_id) in enumerate(zip(docs, metas, ids)):
        score = score_candidate(query, meta, doc)
        scored_results.append({
            "rank_from_chroma": idx + 1,
            "id": doc_id,
            "document": doc,
            "metadata": meta,
            "score": score
        })

    scored_results.sort(key=lambda x: x["score"], reverse=True)
    return scored_results


def build_clean_answer(top_results: List[Dict[str, Any]]) -> str:
    seen = set()
    clean_parts = []

    for res in top_results:
        text = res["document"]
        sentences = re.split(r"(?<=[.?!])\s+", text)

        for s in sentences:
            s = s.strip()
            if not s:
                continue
            key = s.lower()
            if key in seen:
                continue
            seen.add(key)

            if len(s.split()) > 4:
                clean_parts.append(s)

    clean_parts = clean_parts[:6]

    if not clean_parts:
        return "Sorry, I could not build a clean answer from the retrieved knowledge."

    return " ".join(clean_parts).strip()


def build_system_answer(query: str, language: str = "en") -> Dict[str, Any]:
    collection = client.get_collection(name="diabetes_knowledge")

    query = (query or "").strip()
    language = (language or "en").strip()

    detected_intent = detect_intent(query)
    target_categories = INTENT_DB_CATEGORY_MAP.get(detected_intent, ["basics"])

    direct = get_direct_answer(query, detected_intent, target_categories, language)
    if direct:
        return direct

    boosted_query = query.lower()

    boost_terms = {
        "kidney": " kidney nephropathy renal filter waste protein urine",
        "eye": " eye retina retinopathy vision blurred",
        "vision": " eye retina retinopathy vision blurred",
        "nerve": " nerve neuropathy tingling numbness burning",
        "tingling": " nerve neuropathy tingling numbness burning",
        "heart": " heart cardiovascular blood vessels stroke plaque circulation",
        "foot": " foot ulcer wound infection circulation sensation",
        "meal plan": " full day meal plan diet breakfast lunch dinner snack",
        "diet": " plate method vegetables protein carbohydrate portion",
        "walk": " walking 30 minutes 150 minutes after meals exercise",
        "walking": " walking 30 minutes 150 minutes after meals exercise",
    }

    for term, extra in boost_terms.items():
        if term in boosted_query:
            boosted_query += extra

    query_embedding = model.encode([boosted_query]).tolist()

    where_conditions = []
    if language:
        where_conditions.append({"language": language})

    if len(target_categories) == 1:
        where_conditions.append({"category": target_categories[0]})
    else:
        where_conditions.append({"category": {"$in": target_categories}})

    where_filter = where_conditions[0] if len(where_conditions) == 1 else {"$and": where_conditions}

    results = collection.query(
        query_embeddings=query_embedding,
        n_results=15,
        where=where_filter
    )

    if not results["documents"] or not results["documents"][0]:
        return {
            "answer": "Sorry, I could not find a relevant answer.",
            "category": None,
            "categories": target_categories,
            "language": language,
            "intent": detected_intent,
            "retrieved_ids": []
        }

    reranked_results = rerank_results(query, results)

    if not reranked_results:
        return {
            "answer": "Sorry, I could not find a relevant answer.",
            "category": None,
            "categories": target_categories,
            "language": language,
            "intent": detected_intent,
            "retrieved_ids": []
        }

    primary = reranked_results[0]
    top_results = [primary]
    raw_answer = build_clean_answer(top_results)
    combined_answer = rewrite_with_ollama(raw_answer)

    return {
        "answer": combined_answer,
        "category": primary["metadata"].get("category"),
        "categories": target_categories,
        "language": primary["metadata"].get("language", language),
        "intent": detected_intent,
        "retrieved_ids": [r["id"] for r in reranked_results]
    }


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/ask")
def ask_question(request: QueryRequest):
    return build_system_answer(
        query=request.question.strip(),
        language=request.language.strip() if request.language else "en"
    )
