import { jest } from '@jest/globals';
import express from 'express';
import request from 'supertest';

const nominatim = await import('../../src/integrations/nominatim.js');
const { default: geoRoutes } = await import('../../src/routes/geo.js');
const { errorHandler } = await import('../../src/middleware/errorHandler.js');

const app = express();
app.use('/geo', geoRoutes);
app.use(errorHandler);

const place = { lat: '-25.7461', lon: '28.1881', display_name: 'Church Street, Pretoria, South Africa' };

describe('address lookup (Nominatim through our backend)', () => {
  let calls;
  beforeEach(() => {
    nominatim.resetForTests();
    calls = [];
    global.fetch = jest.fn(async (url, options) => {
      calls.push({ url: String(url), at: Date.now(), headers: options.headers });
      return { ok: true, json: async () => (String(url).includes('/reverse') ? place : [place]) };
    });
  });

  test('search: South Africa only, ConnectLocal identifies itself, result shaped for the app', async () => {
    const res = await request(app).get('/geo/search').query({ q: 'Church Street, Pretoria' });
    expect(res.status).toBe(200);
    expect(res.body.data.places).toEqual([{ latitude: -25.7461, longitude: 28.1881, label: place.display_name }]);
    expect(calls[0].url).toContain('countrycodes=za');
    expect(calls[0].headers['User-Agent']).toMatch(/^ConnectLocal\//);
  });

  test('the same search twice is looked up once (cache)', async () => {
    await request(app).get('/geo/search').query({ q: 'Church Street, Pretoria' });
    await request(app).get('/geo/search').query({ q: '  church street,   PRETORIA ' });
    expect(calls).toHaveLength(1);
  });

  test('never more than one Nominatim request per second', async () => {
    await Promise.all([
      nominatim.reverseGeocode(-25.70, 28.10),
      nominatim.reverseGeocode(-25.71, 28.11),
      nominatim.reverseGeocode(-25.72, 28.12)
    ]);
    expect(calls).toHaveLength(3);
    expect(calls[1].at - calls[0].at).toBeGreaterThanOrEqual(1050);
    expect(calls[2].at - calls[1].at).toBeGreaterThanOrEqual(1050);
  }, 10000);

  test('reverse: nearby map spots (~10 m) share one lookup', async () => {
    await nominatim.reverseGeocode(-25.746101, 28.188101);
    await nominatim.reverseGeocode(-25.746104, 28.188104);
    expect(calls).toHaveLength(1);
  });

  test('Nominatim refusing (403/429) or unreachable -> a friendly 502, not a crash', async () => {
    global.fetch = jest.fn(async () => ({ ok: false, status: 403, json: async () => ({}) }));
    let res = await request(app).get('/geo/search').query({ q: 'Somewhere far' });
    expect(res.status).toBe(502);
    expect(res.body.message).toContain('Address search is busy');
    global.fetch = jest.fn(async () => { throw new TypeError('fetch failed'); });
    res = await request(app).get('/geo/search').query({ q: 'Somewhere else' });
    expect(res.status).toBe(502);
    expect(res.body.message).toContain('not available');
  });

  test('bad input -> 400 with the field problem', async () => {
    let res = await request(app).get('/geo/search').query({ q: 'ab' });
    expect(res.status).toBe(400);
    expect(res.body.errors[0]).toMatchObject({ field: 'q' });
    res = await request(app).get('/geo/reverse').query({ lat: 'x', lng: 28 });
    expect(res.status).toBe(400);
    expect(calls).toHaveLength(0);
  });
});
