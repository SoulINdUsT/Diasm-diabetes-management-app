// src/lib/mailer.js
import 'dotenv/config';
import nodemailer from 'nodemailer';

const MAIL_ENABLED = String(process.env.MAIL_ENABLED).toLowerCase() === 'true';

const hasCreds =
  !!process.env.SMTP_HOST &&
  !!process.env.SMTP_USER &&
  !!process.env.SMTP_PASS;

// ✅ Only allow real SMTP if MAIL_ENABLED=true AND creds exist
const useSMTP = MAIL_ENABLED && hasCreds;

let transporter = null;

if (useSMTP) {
  const port = Number(process.env.SMTP_PORT || 587);
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465, // SSL for 465, STARTTLS for 587
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
} else {
  console.log('[mailer] Email disabled (MAIL_ENABLED=false) OR SMTP creds missing. Will log only.');
}

/** -------- DEV OUTBOX (captures tokens for echo endpoints) -------- */
const DEV_OUTBOX = []; // [{to, subject, html, text, at, captured:{verificationToken, resetToken}}]

function captureTokens(html = '', text = '') {
  const out = {};
  const verHtml = html.match(/\/verify-email\?token=([A-Za-z0-9_-]+)/i);
  const verTxt  = text.match(/\/verify-email\?token=([A-Za-z0-9_-]+)/i);
  if (verHtml) out.verificationToken = verHtml[1];
  else if (verTxt) out.verificationToken = verTxt[1];

  const resetHtml = html.match(/\/reset-password\?token=([A-Za-z0-9_-]+)/i);
  const resetTxt  = text.match(/\/reset-password\?token=([A-Za-z0-9_-]+)/i);
  if (resetHtml) out.resetToken = resetHtml[1];
  else if (resetTxt) out.resetToken = resetTxt[1];

  return out;
}

export function devGetLastByEmail(email) {
  if (!email) return {};
  const list = DEV_OUTBOX.filter(
    m => (m.to || '').toLowerCase() === String(email).toLowerCase()
  );
  if (!list.length) return {};
  return list[list.length - 1].captured || {};
}

/** Send an email (or log in dev). Always capture tokens for DEV echo. */
export async function sendMail({ to, subject, html = '', text = '' }) {
  const from = process.env.MAIL_FROM || 'DIAsm <no-reply@diasm.local>';

  const captured = captureTokens(html, text);
  DEV_OUTBOX.push({ to, subject, html, text, at: new Date(), captured });

  if (!useSMTP) {
    console.log('[mailer][dev] To:', to);
    console.log('[mailer][dev] Subject:', subject);
    if (captured.verificationToken) console.log('[mailer] verificationToken:', captured.verificationToken);
    if (captured.resetToken)        console.log('[mailer] resetToken:',        captured.resetToken);
    return { ok: true, dev: true };
  }

  await transporter.sendMail({ from, to, subject, html, text });
  return { ok: true };
}

/** Verify SMTP connectivity at boot (no-op when disabled) */
export async function verifySmtp() {
  if (!useSMTP) {
    console.log('[mailer] verifySmtp skipped (MAIL_ENABLED=false or no creds).');
    return false;
  }
  try {
    await transporter.verify();
    console.log('[mailer] SMTP ok (', process.env.SMTP_HOST, ')');
    return true;
  } catch (e) {
    console.error('[mailer] SMTP failed:', e?.message || e);
    return false;
  }
}
