/**
 * Simple in-memory rate limits (one server instance; no extra package). Each limit counts requests per key
 * (the caller's IP, plus e.g. the email or the signed-in user) in a fixed window and answers 429 with
 * Retry-After when it is used up.
 *
 * Limits (per window):
 *   login            10 per 15 min per IP + email   (password guessing)
 *   register         10 per hour per IP
 *   passwordReset     5 per hour per IP + email
 *   otpVerify        10 per 15 min per user          (on top of the 5 tries per code)
 *   paymentIntent    20 per 10 min per user
 */

import { AppError } from '../utils/errors.js';

const MAX_KEYS = 20000;

export const rateLimit = ({
  name, windowMs, max, key = (req) => req.ip, message
}) => {
  const hits = new Map(); // key -> { count, resetAt }
  return (req, res, next) => {
    const now = Date.now();
    const id = `${name}:${key(req)}`;
    const entry = hits.get(id);
    if (!entry || entry.resetAt <= now) {
      if (hits.size >= MAX_KEYS) hits.clear(); // never grows without bound
      hits.set(id, { count: 1, resetAt: now + windowMs });
      return next();
    }
    entry.count += 1;
    if (entry.count > max) {
      res.set('Retry-After', String(Math.ceil((entry.resetAt - now) / 1000)));
      return next(new AppError(message || 'Too many attempts. Please wait a few minutes and try again.', 429, 'RATE_LIMITED'));
    }
    return next();
  };
};

const email = (req) => String(req.body?.email || '').trim().toLowerCase();
const user = (req) => req.user?.id || req.ip;

export const limits = {
  login: rateLimit({
    name: 'login',
    windowMs: 15 * 60000,
    max: 10,
    key: (req) => `${req.ip}:${email(req)}`,
    message: 'Too many sign-in attempts. Please wait 15 minutes, or reset your password.'
  }),
  register: rateLimit({ name: 'register', windowMs: 60 * 60000, max: 10 }),
  passwordReset: rateLimit({
    name: 'password-reset', windowMs: 60 * 60000, max: 5, key: (req) => `${req.ip}:${email(req)}`
  }),
  otpVerify: rateLimit({
    name: 'otp-verify', windowMs: 15 * 60000, max: 10, key: user
  }),
  paymentIntent: rateLimit({
    name: 'payment-intent', windowMs: 10 * 60000, max: 20, key: user, message: 'Too many payment attempts. Please wait a few minutes.'
  })
};

export default { rateLimit, limits };
