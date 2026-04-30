
// src/app.js
import express from "express";
import cors from "cors";
import path from "path";
import { fileURLToPath } from "url";

import authRoutes from "./modules/auth/auth.routes.js";
import riskRoutes from "./modules/risk/risk.routes.js";
import educationRoutes from "./modules/education/education.routes.js";
import metricsRoutes from "./modules/metrics/metrics.routes.js";
import lifestyleRoutes from "./modules/lifestyle/lifestyle.routes.js";
import reminderRoutes from "./modules/reminders/reminder.routes.js";
import chatbotRoutes from "./modules/chatbot/chatbot.routes.js";
import calcRoutes from "./modules/calc/calc.routes.js";
import hydrationRoutes from "./modules/lifestyle/hydration/hydration.routes.js";
import rightPathRoutes from "./modules/rightpath/rightpath.routes.js";

const app = express();

// ✅ CORS must be BEFORE routes
const corsOptions = {
  origin: true,
  credentials: true,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
};

app.use(cors(corsOptions));
app.options("*", cors(corsOptions)); // ✅ preflight

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

app.use("/uploads", express.static(path.join(__dirname, "../public/uploads")));

app.get("/api/v1/health", (_req, res) => res.json({ ok: true }));

app.use("/api/v1/auth", authRoutes);
app.use("/api/v1/risk", riskRoutes);
app.use("/api/v1/education", educationRoutes);
app.use("/api/v1/metrics", metricsRoutes);
app.use("/api/v1/lifestyle", lifestyleRoutes);
app.use("/api/v1/reminders", reminderRoutes);
app.use("/api/v1/chatbot", chatbotRoutes);
app.use("/api/v1/calc", calcRoutes);
app.use("/api/v1/hydration", hydrationRoutes);
app.use("/api/v1/right-path", rightPathRoutes);

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: "Server error", message: err.message });
});

export default app;
