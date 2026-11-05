/**
 * Short secret codes: the 4-digit arrival PIN and the 6-digit phone OTP.
 *
 * Only HMAC-SHA256 hashes are stored in the database, keyed with CODE_HASH_SECRET (a server-side
 * "pepper"). A 4- or 6-digit code has so few combinations that a plain hash could be reversed instantly
 * from a database leak; without the server secret it cannot.
 *
 * The arrival PIN is *derived* from the booking id and the secret, so the backend can show it to the
 * customer again at any time without ever storing the PIN itself.
 */

import crypto from 'node:crypto';

const MIN_SECRET_LENGTH = 32;

const getSecret = () => {
  const secret = process.env.CODE_HASH_SECRET;
  if (!secret || secret.length < MIN_SECRET_LENGTH) {
    throw new Error(`CODE_HASH_SECRET must be set in backend/.env (at least ${MIN_SECRET_LENGTH} characters)`);
  }
  return secret;
};

export const assertCodeSecretConfigured = () => {
  getSecret();
};

const hmac = (...parts) => crypto.createHmac('sha256', getSecret()).update(parts.join(':')).digest();

/** Constant-time comparison of two hex digests. */
export const hashesMatch = (expectedHex, actualHex) => {
  if (typeof expectedHex !== 'string' || typeof actualHex !== 'string' || expectedHex.length !== actualHex.length) {
    return false;
  }
  return crypto.timingSafeEqual(Buffer.from(expectedHex, 'hex'), Buffer.from(actualHex, 'hex'));
};

// ---- Arrival PIN (4 digits) ---------------------------------------------------------------------------
export const deriveArrivalPin = (bookingId) => String(hmac('arrival-pin', bookingId).readUInt32BE(0) % 10000)
  .padStart(4, '0');

export const hashArrivalPin = (bookingId, pin) => hmac('arrival-pin-hash', bookingId, String(pin)).toString('hex');

// ---- Phone OTP (6 digits) -----------------------------------------------------------------------------
export const generateOtp = () => String(crypto.randomInt(0, 1000000)).padStart(6, '0');

export const hashOtp = (userId, phoneNumber, code) => hmac('phone-otp', userId, phoneNumber, String(code))
  .toString('hex');
