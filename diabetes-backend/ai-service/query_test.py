import re
from pathlib import Path
from typing import List, Dict, Any

import chromadb
from sentence_transformers import SentenceTransformer


# Load same model used during storage
model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

# Connect to Chroma
db_path = Path(__file__).resolve().parent / "chroma_db"
client = chromadb.PersistentClient(path=str(db_path))
collection = client.get_collection(name="diabetes_knowledge")


# Intent database category mapping
INTENT_DB_CATEGORY_MAP = {
    "basics_info": ["basics"],
    "diagnosis_tests": ["basics"],
    "symptoms_risk": ["basics"],

    "complications_general": ["complications", "type2"],
    "complications_eyes": ["complications", "type2"],
    "complications_kidneys": ["complications", "type2"],
    "complications_nerves": ["complications", "type2"],
    "complications_heart_vessels": ["complications", "type2"],
    "complications_feet": ["complications", "type2"],

    "exercise_guidance": ["exercise", "lifestyle"],
    "exercise_safety": ["exercise", "lifestyle"],

    "nutrition_general": ["nutrition", "diet"],
    "nutrition_high_sugar": ["nutrition", "diet"],
    "meal_plan_request": ["nutrition", "diet"],
    "nutrition_night_eating": ["nutrition", "diet"],
    "nutrition_eating_out": ["nutrition", "diet"],
    "nutrition_hunger_management": ["nutrition", "diet"],

    "mental_health_stress_anxiety": ["mental_health", "mental health"],
    "mental_health_burnout": ["mental_health", "mental health"],
    "mental_health_depression_hopelessness": ["mental_health", "mental health"],
    "mental_health_support_connection": ["mental_health", "mental health"],
    "mental_health_relaxation_tools": ["mental_health", "mental health"],
}


def normalize_text(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r"[^\w\s]", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text


def has_any(text: str, keywords: List[str]) -> bool:
    return any(keyword in text for keyword in keywords)


def detect_intent(question: str) -> str:
    q = normalize_text(question)

    # Mental health
    if has_any(q, [
        "i hate this disease", "i hate this illness", "hate this disease", "hate this illness",
        "stressed", "stress", "anxious", "anxiety", "worried", "worry", "panic", "overwhelmed"
    ]):
        return "mental_health_stress_anxiety"

    if has_any(q, [
        "burnout", "burned out", "tired of diabetes", "tired of checking sugar",
        "tired of checking blood sugar", "frustrated with diabetes",
        "fed up with diabetes", "done with diabetes"
    ]):
        return "mental_health_burnout"

    if has_any(q, [
        "depressed", "hopeless", "feel like giving up", "giving up on diabetes",
        "cannot do this anymore", "can t do this anymore", "sad", "low mood"
    ]):
        return "mental_health_depression_hopelessness"

    if has_any(q, [
        "support group", "family support", "friends support", "talk to someone",
        "who can support me", "who can help me emotionally"
    ]):
        return "mental_health_support_connection"

    if has_any(q, [
        "breathing exercise", "meditation", "relaxation", "grounding",
        "calm me down", "stretching", "yoga"
    ]):
        return "mental_health_relaxation_tools"

    # Exercise
    if has_any(q, [
        "safe before exercise", "sugar before exercise", "low blood sugar during exercise",
        "sugar drops during workout", "precautions before exercise", "when should exercise be avoided",
        "exercise safety", "exercise precautions", "exercise with insulin", "exercise with complications"
    ]):
        return "exercise_safety"

    if has_any(q, [
        "exercise", "workout", "walking", "aerobic", "strength training",
        "how much exercise", "best time to exercise", "beginner exercise", "physical activity"
    ]):
        return "exercise_guidance"

    # Nutrition
    if has_any(q, [
        "meal plan", "diet plan", "1200 kcal", "1400 kcal", "1600 kcal", "1800 kcal", "2000 kcal",
        "full day meal plan", "what should i eat all day"
    ]):
        return "meal_plan_request"

    if has_any(q, [
        "late night", "at night", "before bed", "night snack", "eat at night"
    ]):
        return "nutrition_night_eating"

    if has_any(q, [
        "restaurant", "outside food", "eating outside", "fast food", "biryani", "eat out"
    ]):
        return "nutrition_eating_out"

    if has_any(q, [
        "always hungry", "hungry all the time", "control hunger", "frequent hunger", "appetite"
    ]):
        return "nutrition_hunger_management"

    if has_any(q, [
        "high sugar", "sugar is high", "blood sugar is high", "hyperglycemia",
        "what to eat when sugar is high"
    ]):
        return "nutrition_high_sugar"

    if has_any(q, [
        "rice", "roti", "fruit", "banana", "mango", "breakfast", "lunch", "dinner",
        "snack", "carbohydrate", "protein", "plate method", "what should i eat",
        "foods to avoid", "healthy eating", "diet"
    ]):
        return "nutrition_general"

    # Complications
    if has_any(q, [
        "eyes", "eye", "retina", "retinopathy", "blurred vision", "floaters", "vision loss"
    ]):
        return "complications_eyes"

    if has_any(q, [
        "kidney", "kidneys", "nephropathy", "protein in urine", "urine protein",
        "swelling from kidney", "kidney damage"
    ]):
        return "complications_kidneys"

    if has_any(q, [
        "nerve", "nerves", "neuropathy", "tingling", "numbness", "burning pain", "loss of sensation"
    ]):
        return "complications_nerves"

    if has_any(q, [
        "heart disease", "heart", "stroke", "blood vessels", "circulation", "arteries", "cardiovascular"
    ]):
        return "complications_heart_vessels"

    if has_any(q, [
        "foot", "feet", "foot ulcer", "foot problem", "wound", "amputation", "shoe"
    ]):
        return "complications_feet"

    if has_any(q, [
        "complication", "complications", "organ damage", "damage the body",
        "not treated", "untreated diabetes", "long term effects"
    ]):
        return "complications_general"

    # Diagnosis / tests
    if has_any(q, [
        "a1c", "hba1c", "fasting blood sugar", "fasting glucose", "random blood sugar",
        "random glucose", "oral glucose tolerance", "ogtt", "diagnose", "diagnosis",
        "tested", "test", "screened", "screening", "who should be screened"
    ]):
        return "diagnosis_tests"

    # Symptoms / risk
    if has_any(q, [
        "symptom", "symptoms", "signs", "warning signs", "thirsty", "urinate a lot",
        "frequent urination", "fatigue", "blurred vision", "weight loss",
        "am i high risk", "risk", "risk factors", "family history", "overweight"
    ]):
        return "symptoms_risk"

    # Default
    return "basics_info"


def get_query_keywords(query: str) -> List[str]:
    """
    Keep only meaningful query words for simple reranking.
    """
    stop_words = {
        "what", "is", "are", "the", "of", "a", "an", "how", "does", "do", "can",
        "why", "when", "should", "i", "my", "in", "on", "for", "to", "and"
    }
    words = normalize_text(query).split()
    return [w for w in words if w not in stop_words and len(w) > 2]


def score_candidate(query: str, metadata: Dict[str, Any], document: str) -> int:
    """
    Simple reranking score.
    Higher score = better candidate.
    """
    score = 0

    query_norm = normalize_text(query)
    title_norm = normalize_text(metadata.get("title", ""))
    doc_norm = normalize_text(document)

    query_keywords = get_query_keywords(query)

    # 1. Strong title keyword overlap
    for kw in query_keywords:
        if kw in title_norm:
            score += 10

    # 2. Small document keyword overlap
    for kw in query_keywords:
        if kw in doc_norm:
            score += 3

    # 3. Definition-style question bonus
    if query_norm.startswith("what is ") or query_norm.startswith("what are "):
        if "what" in title_norm:
            score += 2

    # 4. Very targeted concept bonuses
    targeted_terms = ["glucose", "insulin", "prediabetes", "diabetes", "causes", "cause"]
    for term in targeted_terms:
        if term in query_norm and term in title_norm:
            score += 15

    return score


def pick_best_result(query: str, results: Dict[str, Any]) -> Dict[str, Any]:
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
    return scored_results[0], scored_results


# =========================
# Test query
# =========================
query = "when i should exercise?"
language = "en"

detected_intent = detect_intent(query)
target_categories = INTENT_DB_CATEGORY_MAP.get(detected_intent, ["basics"])

query_embedding = model.encode([query]).tolist()

where_conditions = []

if language:
    where_conditions.append({"language": language})

if len(target_categories) == 1:
    where_conditions.append({"category": target_categories[0]})
else:
    where_conditions.append({"category": {"$in": target_categories}})

if len(where_conditions) == 1:
    where_filter = where_conditions[0]
else:
    where_filter = {"$and": where_conditions}

results = collection.query(
    query_embeddings=query_embedding,
    n_results=3,
    where=where_filter
)

print("Query:", query)
print("Language:", language)
print("Detected Intent:", detected_intent)
print("Target Categories:", target_categories)
print("Where Filter:", where_filter)

print("\nTop IDs:")
print(results["ids"][0])

print("\nTop Metadatas:")
for i, meta in enumerate(results["metadatas"][0], start=1):
    print(f"Result {i} Metadata:", meta)

if results["documents"] and results["documents"][0]:
    best_result, scored_results = pick_best_result(query, results)

    print("\nReranked Results:")
    for item in scored_results:
        print(
            f"Chroma Rank={item['rank_from_chroma']} | "
            f"Score={item['score']} | "
            f"ID={item['id']} | "
            f"Title={item['metadata'].get('title', '')}"
        )

    print("\nBest Answer After Reranking:")
    print(f"{best_result['metadata']['title']}:")
    print(best_result["document"])
else:
    print("\nNo matching result found.")