import { getAnswer } from './chatbot.service.js';

export async function ask(req, res) {
  try {
    const { message = '', lang } = req.body || {};
    if (!message || typeof message !== 'string' || !message.trim()) {
      return res.status(400).json({ error: 'message is required' });
    }

    const result = await getAnswer(message.trim(), lang);
    return res.json(result);
  } catch (err) {
    console.error('[chatbot.ask] error:', err);
    return res.status(500).json({ error: 'Something went wrong' });
  }
}
