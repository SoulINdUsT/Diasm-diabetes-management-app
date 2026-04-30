import json
from pathlib import Path
from typing import List, Dict, Any

from main import build_system_answer


eval_path = Path(__file__).resolve().parent / "evaluation_questions.json"
with open(eval_path, "r", encoding="utf-8") as f:
    evaluation_data = json.load(f)


def normalize_for_match(text: str) -> str:
    return " ".join(text.lower().strip().split())


def keyword_match_score(answer: str, expected_keywords: List[str]) -> Dict[str, Any]:
    answer_norm = normalize_for_match(answer)

    matched = []
    missing = []

    for kw in expected_keywords:
        kw_norm = normalize_for_match(kw)
        if kw_norm in answer_norm:
            matched.append(kw)
        else:
            missing.append(kw)

    total = len(expected_keywords)
    matched_count = len(matched)

    if total == 0:
        return {
            "label": "N/A",
            "score": None,
            "matched": matched,
            "missing": missing,
        }

    score = matched_count / total

    if matched_count == total:
        label = "PASS"
    elif matched_count > 0:
        label = "PARTIAL"
    else:
        label = "FAIL"

    return {
        "label": label,
        "score": score,
        "matched": matched,
        "missing": missing,
    }


total = len(evaluation_data)

intent_correct = 0
category_correct = 0
top1_correct = 0
top3_correct = 0

answer_pass = 0
answer_partial = 0
answer_fail = 0
answer_score_sum = 0.0

print("\n===== EVALUATION RESULTS =====\n")

for idx, item in enumerate(evaluation_data, start=1):
    question = item["question"]
    result = build_system_answer(query=question, language="en")

    if result["intent"] == item["expected_intent"]:
        intent_correct += 1

    got_categories = result.get("categories", [result["category"]] if result.get("category") else [])
    if set(got_categories) == set(item["expected_categories"]):
        category_correct += 1

    ids = result.get("retrieved_ids", [])

    if ids:
        if ids[0] in item["expected_chunk_ids"]:
            top1_correct += 1

        if any(i in item["expected_chunk_ids"] for i in ids[:3]):
            top3_correct += 1

    match = keyword_match_score(result["answer"], item["expected_answer_keywords"])

    if match["label"] == "PASS":
        answer_pass += 1
    elif match["label"] == "PARTIAL":
        answer_partial += 1
    elif match["label"] == "FAIL":
        answer_fail += 1

    if match["score"] is not None:
        answer_score_sum += match["score"]

    print(f"{idx}. {question}")
    print(f"   Intent   : expected={item['expected_intent']} | got={result['intent']}")
    print(f"   Category : expected={item['expected_categories']} | got={got_categories}")
    print(f"   Top-3 IDs: {ids[:3]}")
    print(f"   Answer   : {match['label']} | matched={match['matched']} | missing={match['missing']}")
    print("-" * 90)

print("\n===== FINAL METRICS =====")
print(f"Total Questions       : {total}")
print(f"Intent Accuracy       : {intent_correct}/{total} = {intent_correct / total:.2%}")
print(f"Category Accuracy     : {category_correct}/{total} = {category_correct / total:.2%}")
print(f"Top-1 Retrieval Acc   : {top1_correct}/{total} = {top1_correct / total:.2%}")
print(f"Top-3 Retrieval Acc   : {top3_correct}/{total} = {top3_correct / total:.2%}")

avg_score = answer_score_sum / total if total > 0 else 0.0

print("\n===== ANSWER RESPONSE ACCURACY =====")
print(f"PASS    : {answer_pass}")
print(f"PARTIAL : {answer_partial}")
print(f"FAIL    : {answer_fail}")
print(f"Average : {avg_score:.2%}")