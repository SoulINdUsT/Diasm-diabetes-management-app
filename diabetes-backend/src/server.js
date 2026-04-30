// src/server.js
import 'dotenv/config';


import app from './app.js';
import { verifySmtp } from './lib/mailer.js';

const PORT = process.env.PORT || 3000;

(async () => {
  // Check SMTP once on startup (prints clear status to console)
  await verifySmtp();

 app.listen(PORT, '0.0.0.0', () => {
  console.log(`API running on http://0.0.0.0:${PORT}`);
});

})().catch((err) => {
  console.error('Startup failed:', err);
  process.exit(1);
});



