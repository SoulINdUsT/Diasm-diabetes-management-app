import fs from "fs";

const data = JSON.parse(
  fs.readFileSync("./ai-data/knowledge_base.json", "utf-8")
);

const documents = data.map(item => item.retrieval_text);
const metadatas = data.map(item => ({
  category: item.category,
  language: item.language,
  title: item.section_title
}));
const ids = data.map(item => item.id);

console.log("Documents sample:", documents[0]);
console.log("Metadata sample:", metadatas[0]);
console.log("ID sample:", ids[0]);