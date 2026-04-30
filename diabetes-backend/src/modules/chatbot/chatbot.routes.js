import { Router } from 'express';
import * as ChatbotController from './chatbot.controller.js';

const router = Router();

// Health check
router.get('/health', (_req, res) => res.json({ ok: true, module: 'chatbot' }));

// Main Q&A endpoint
router.post('/ask', ChatbotController.ask);

export default router;
