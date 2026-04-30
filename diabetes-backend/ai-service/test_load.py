import json
from pathlib import Path

json_path = Path(__file__).resolve().parent.parent / "ai-data" / "knowledge_base.json"

with open(json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

documents = [item["retrieval_text"] for item in data]
metadatas = [
    {
        "category": item["category"],
        "language": item["language"],
        "title": item["section_title"],
    }
    for item in data
]
ids = [item["id"] for item in data]

print("Total chunks:", len(data))
print("First document:", documents[0])
print("First metadata:", metadatas[0])
print("First id:", ids[0])