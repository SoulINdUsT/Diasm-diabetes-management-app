const fs = require('fs');

const inputFile = 'src/modules/chatbot/prompts/diabetes_basics.txt';
const outputFile = 'src/modules/chatbot/prompts/diabetes_basics.json';

const text = fs.readFileSync(inputFile, 'utf-8');

// Split by empty lines
const blocks = text.split('\n\n');

const data = blocks.map(block => {
  const lines = block.split('\n');
  
  return {
    question: lines[0]?.trim(),
    answer: lines.slice(1).join(' ').trim()
  };
});

// Remove empty entries
const cleanData = data.filter(item => item.question && item.answer);

fs.writeFileSync(outputFile, JSON.stringify(cleanData, null, 2));

console.log('✅ Converted to JSON successfully');