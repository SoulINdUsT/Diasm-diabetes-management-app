// src/lib/crypto.js
import argon2 from 'argon2';
import crypto from 'crypto';

export async function hashPassword(password) {
  return argon2.hash(password, { type: argon2.argon2id });
}

export async function verifyPassword(hash, plain) {
  return argon2.verify(hash, plain);
}

export function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}
