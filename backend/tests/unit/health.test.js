import { jest } from '@jest/globals';
import express from 'express';
import request from 'supertest';

const queryResult = { current: null };
const query = {
  select: jest.fn(() => query),
  abortSignal: jest.fn(() => Promise.resolve(queryResult.current))
};
const supabaseAdmin = { from: jest.fn(() => query) };

jest.unstable_mockModule('../../src/config/supabase.js', () => ({ supabase: {}, supabaseAdmin }));
const { default: healthRoutes } = await import('../../src/routes/health.js');

const app = express();
app.use('/health', healthRoutes);

describe('Health routes', () => {
  beforeEach(() => jest.clearAllMocks());

  test('GET /health returns ok without touching the database', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(supabaseAdmin.from).not.toHaveBeenCalled();
  });

  test('GET /health/db counts service_categories and returns ok', async () => {
    queryResult.current = { count: 3, error: null, status: 200 };
    const res = await request(app).get('/health/db');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'ok', database: 'connected', serviceCategories: 3 });
    expect(supabaseAdmin.from).toHaveBeenCalledWith('service_categories');
    expect(query.select).toHaveBeenCalledWith('*', { count: 'exact', head: true });
  });

  test('GET /health/db returns 503 with the error when the query fails', async () => {
    queryResult.current = {
      count: null, error: { message: '' }, status: 401, statusText: 'Unauthorized'
    };
    const res = await request(app).get('/health/db');
    expect(res.status).toBe(503);
    expect(res.body.status).toBe('error');
    expect(res.body.error).toMatchObject({ code: 'HTTP_401', message: 'Unauthorized' });
  });
});
