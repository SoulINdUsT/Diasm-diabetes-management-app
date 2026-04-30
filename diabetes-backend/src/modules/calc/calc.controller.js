// src/modules/calc/calc.controller.js

function sendBad(res, msg) {
  return res.status(400).json({ error: msg });
}

function bmiFromKgCm(kg, cm) {
  const m = cm / 100;
  const bmi = kg / (m * m);
  return Math.round(bmi * 10) / 10; // 1 decimal
}

function bmiCategoryWHO(bmi) {
  if (bmi < 18.5) return "Underweight";
  if (bmi < 25) return "Normal";
  if (bmi < 30) return "Overweight";
  return "Obese";
}

function bmrMifflinStJeor({ sex, kg, cm, age }) {
  const base = 10 * kg + 6.25 * cm - 5 * age;
  return sex === "male" ? base + 5 : base - 161;
}

function activityFactor(level) {
  switch (level) {
    case "light": return 1.375;
    case "moderate": return 1.55;
    case "active": return 1.725;
    case "very_active": return 1.9;
    case "sedentary":
    default: return 1.2;
  }
}

// GET /api/v1/calc/bmi?kg=&cm=
export async function calcBmi(req, res) {
  const kg = Number(req.query.kg);
  const cm = Number(req.query.cm);
  if (!kg || !cm) return sendBad(res, "kg and cm are required numbers");

  const bmi = bmiFromKgCm(kg, cm);
  const category = bmiCategoryWHO(bmi);

  res.json({ kg, cm, bmi, category });
}

// GET /api/v1/risk/bmi-opt?kg=&cm=
export async function bmiToIdrsOption(req, res) {
  const kg = Number(req.query.kg);
  const cm = Number(req.query.cm);
  if (!kg || !cm) return sendBad(res, "kg and cm are required numbers");

  const bmi = bmiFromKgCm(kg, cm);

  let opt_code = "BMI_UNDER_25";
  if (bmi >= 25 && bmi < 30) opt_code = "BMI_25_29";
  if (bmi >= 30) opt_code = "BMI_30_PLUS";

  res.json({ kg, cm, bmi, opt_code });
}

// GET /api/v1/calc/bmr?sex=&age=&kg=&cm=&activity_level=
export async function calcBmr(req, res) {
  const sexRaw = (req.query.sex || "").toString().trim().toLowerCase();
  const age = Number(req.query.age);
  const kg = Number(req.query.kg);
  const cm = Number(req.query.cm);
  const activity_level = (req.query.activity_level || "sedentary")
    .toString()
    .trim()
    .toLowerCase();

  if (sexRaw !== "male" && sexRaw !== "female") {
    return sendBad(res, "sex must be male or female");
  }
  if (!age || !kg || !cm) {
    return sendBad(res, "age, kg, and cm are required numbers");
  }

  const bmr = bmrMifflinStJeor({ sex: sexRaw, kg, cm, age });
  const factor = activityFactor(activity_level);
  const calories = bmr * factor;

  res.json({
    sex: sexRaw,
    age,
    kg,
    cm,
    activity_level,
    bmr: Math.round(bmr),
    daily_calories: Math.round(calories),
  });
}
