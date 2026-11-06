/**
 * Field encryption for sensitive values at rest (bank account numbers).
 *
 * AES-256-GCM with a random 12-byte IV per value; the auth tag makes any change to the stored value fail to
 * decrypt. Stored as "v1:<iv>:<tag>:<ciphertext>" (base64). The key is PAYOUT_ENCRYPTION_KEY in backend/.env
 * (32 bytes, base64). Losing the key makes stored account numbers unreadable; rotating it needs a
 * re-encryption pass, so treat it like the database password.
 */

import crypto from 'node:crypto';

const VERSION = 'v1';

const getKey = () => {
  const encoded = process.env.PAYOUT_ENCRYPTION_KEY || '';
  const key = Buffer.from(encoded, 'base64');
  if (key.length !== 32) {
    throw new Error('PAYOUT_ENCRYPTION_KEY must be set in backend/.env (32 bytes, base64)');
  }
  return key;
};

export const assertEncryptionKeyConfigured = () => {
  getKey();
};

export const encryptField = (plaintext) => {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', getKey(), iv);
  const ciphertext = Buffer.concat([cipher.update(String(plaintext), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [VERSION, iv.toString('base64'), tag.toString('base64'), ciphertext.toString('base64')].join(':');
};

export const decryptField = (stored) => {
  const [version, iv, tag, ciphertext] = String(stored || '').split(':');
  if (version !== VERSION || !iv || !tag || !ciphertext) throw new Error('Unsupported encrypted value');
  const decipher = crypto.createDecipheriv('aes-256-gcm', getKey(), Buffer.from(iv, 'base64'));
  decipher.setAuthTag(Buffer.from(tag, 'base64'));
  return Buffer.concat([decipher.update(Buffer.from(ciphertext, 'base64')), decipher.final()]).toString('utf8');
};

export default { encryptField, decryptField, assertEncryptionKeyConfigured };
