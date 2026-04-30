import json
from pathlib import Path
import chromadb
from sentence_transformers import SentenceTransformer

# Load JSON knowledge base
json_path = Path(__file__).resolve().parent.parent / "ai-data" / "knowledge_base.json"

with open(json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

# Prepare Chroma inputs
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

# Load embedding model
model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")
embeddings = model.encode(documents).tolist()

# Persistent Chroma path
db_path = Path(__file__).resolve().parent / "chroma_db"
client = chromadb.PersistentClient(path=str(db_path))

collection_name = "diabetes_knowledge"

# Delete old collection if it exists
try:
    client.delete_collection(name=collection_name)
    print("Old collection deleted.")
except Exception:
    print("No old collection found. Creating fresh collection.")

# Create fresh collection
collection = client.get_or_create_collection(name=collection_name)

# Add all data
collection.add(
    documents=documents,
    metadatas=metadatas,
    ids=ids,
    embeddings=embeddings
)

print(f"Stored {len(documents)} chunks in Chroma successfully!")