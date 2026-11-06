/**
 * Address lookup with OpenStreetMap Nominatim, done by the backend for every app (phone and web):
 *   - identifies ConnectLocal properly (Nominatim answers 403 to apps that don't),
 *   - never more than 1 request per second for the whole server (Nominatim's usage policy),
 *   - caches answers, so the same address or map spot is only looked up once.
 * Policy: https://operations.osmfoundation.org/policies/nominatim/ (results need "© OpenStreetMap contributors").
 */

import logger from '../utils/logger.js';
import { ExternalServiceError } from '../utils/errors.js';

const BASE_URL = () => (process.env.NOMINATIM_URL || 'https://nominatim.openstreetmap.org').replace(/\/+$/, '');
const USER_AGENT = () => process.env.NOMINATIM_USER_AGENT
  || 'ConnectLocal/1.0 (student marketplace project; +https://github.com/Katlegomalema/connectlocal)';
const MIN_GAP_MS = 1100; // a little over 1 request per second
const TIMEOUT_MS = 8000;
const CACHE_MAX = 2000;
const CACHE_TTL_MS = 7 * 24 * 3600 * 1000;

const cache = new Map(); // key -> { value, expires } (Map keeps insertion order: oldest first)
let queue = Promise.resolve();
let lastCallAt = 0;

const cached = (key) => {
  const hit = cache.get(key);
  if (!hit) return undefined;
  if (hit.expires < Date.now()) {
    cache.delete(key);
    return undefined;
  }
  cache.delete(key); // move to the end (recently used)
  cache.set(key, hit);
  return hit.value;
};

const remember = (key, value) => {
  cache.set(key, { value, expires: Date.now() + CACHE_TTL_MS });
  while (cache.size > CACHE_MAX) cache.delete(cache.keys().next().value);
};

/** Runs [task] after the previous one, at least MIN_GAP_MS after the previous upstream call. */
const throttled = (task) => {
  const run = queue.then(async () => {
    const wait = lastCallAt + MIN_GAP_MS - Date.now();
    if (wait > 0) await new Promise((resolve) => { setTimeout(resolve, wait); });
    lastCallAt = Date.now();
    return task();
  });
  queue = run.catch(() => {}); // one failure must not block the next lookups
  return run;
};

const fetchJson = async (path, params) => {
  const url = new URL(`${BASE_URL()}${path}`);
  for (const [key, value] of Object.entries({ ...params, format: 'jsonv2', 'accept-language': 'en' })) {
    url.searchParams.set(key, String(value));
  }
  if (process.env.NOMINATIM_EMAIL) url.searchParams.set('email', process.env.NOMINATIM_EMAIL);
  let response;
  try {
    response = await fetch(url, {
      headers: { 'User-Agent': USER_AGENT(), Accept: 'application/json' },
      signal: AbortSignal.timeout(TIMEOUT_MS)
    });
  } catch (error) {
    logger.warn({ err: error, path }, 'Address lookup could not reach Nominatim');
    throw new ExternalServiceError('Address search is not available right now. Please try again.', 'nominatim');
  }
  if (!response.ok) {
    logger.warn({ status: response.status, path }, 'Nominatim refused an address lookup');
    throw new ExternalServiceError('Address search is busy right now. Please try again in a moment.', 'nominatim');
  }
  return response.json();
};

/** Places matching [query] in South Africa (best first, at most [limit]). */
export const searchAddress = async (query, limit = 5) => {
  const q = String(query || '').trim().replace(/\s+/g, ' ');
  const key = `s:${q.toLowerCase()}:${limit}`;
  const hit = cached(key);
  if (hit) return hit;
  const rows = await throttled(() => fetchJson('/search', {
    q, limit, countrycodes: 'za', addressdetails: 0
  }));
  const places = (Array.isArray(rows) ? rows : []).map((row) => ({
    latitude: Number(row.lat),
    longitude: Number(row.lon),
    label: row.display_name || null
  })).filter((p) => Number.isFinite(p.latitude) && Number.isFinite(p.longitude));
  remember(key, places);
  return places;
};

/** The address at a map spot (rounded to ~10 m, so small map moves share one lookup). */
export const reverseGeocode = async (latitude, longitude) => {
  const lat = Number(latitude).toFixed(4);
  const lng = Number(longitude).toFixed(4);
  const key = `r:${lat},${lng}`;
  const hit = cached(key);
  if (hit !== undefined) return hit;
  const row = await throttled(() => fetchJson('/reverse', { lat, lon: lng, zoom: 18 }));
  const place = row && row.display_name
    ? { latitude: Number(row.lat), longitude: Number(row.lon), label: row.display_name }
    : null;
  remember(key, place);
  return place;
};

/** Tests only. */
export const resetForTests = () => {
  cache.clear();
  queue = Promise.resolve();
  lastCallAt = 0;
};

export default { searchAddress, reverseGeocode };
