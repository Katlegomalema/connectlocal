/**
 * Address lookup for the apps (no Google key, works the same on phones and on the web):
 *   GET /api/v1/geo/search?q=Church Street, Pretoria   -> { places: [{ latitude, longitude, label }] }
 *   GET /api/v1/geo/reverse?lat=-25.74&lng=28.19        -> { place: { latitude, longitude, label } | null }
 * Data © OpenStreetMap contributors (Nominatim). Each address is looked up once and cached.
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { AppError } from '../utils/errors.js';
import { reverseGeocode, searchAddress } from '../integrations/nominatim.js';
import { lineSchema } from '../utils/validators.js';

const router = express.Router();

// Per-address limit so one app cannot use up the shared 1-request-per-second budget.
const WINDOW_MS = 60000;
const MAX_PER_WINDOW = 40;
const hits = new Map(); // ip -> { count, resetAt }

const limitPerClient = (req, res, next) => {
  const now = Date.now();
  const entry = hits.get(req.ip);
  if (!entry || entry.resetAt < now) {
    hits.set(req.ip, { count: 1, resetAt: now + WINDOW_MS });
    if (hits.size > 5000) hits.clear();
    return next();
  }
  entry.count += 1;
  if (entry.count > MAX_PER_WINDOW) {
    res.set('Retry-After', String(Math.ceil((entry.resetAt - now) / 1000)));
    return next(new AppError('Too many address searches. Please wait a minute.', 429, 'RATE_LIMITED'));
  }
  return next();
};

const searchQuery = z.object({ q: lineSchema(200, { min: 3, label: 'The address' }) });
const reverseQuery = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180)
});

const parse = (schema, query) => {
  const result = schema.safeParse(query);
  if (!result.success) {
    const errors = result.error.issues.map((issue) => ({ field: issue.path.join('.'), message: issue.message }));
    throw Object.assign(new AppError(errors[0]?.message || 'Invalid request', 400, 'VALIDATION_ERROR'), { errors });
  }
  return result.data;
};

router.get('/search', limitPerClient, asyncHandler(async (req, res) => {
  const { q } = parse(searchQuery, req.query);
  res.set('Cache-Control', 'public, max-age=86400');
  res.status(200).json({ success: true, data: { places: await searchAddress(q) } });
}));

router.get('/reverse', limitPerClient, asyncHandler(async (req, res) => {
  const { lat, lng } = parse(reverseQuery, req.query);
  res.set('Cache-Control', 'public, max-age=86400');
  res.status(200).json({ success: true, data: { place: await reverseGeocode(lat, lng) } });
}));

export default router;
