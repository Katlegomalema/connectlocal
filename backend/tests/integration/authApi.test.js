import request from 'supertest';
import app from '../../src/app.js';

describe('REST API health and authentication routes', () => {
  test('reports API liveness', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
  });

  test('validates registration input before calling Supabase', async () => {
    const response = await request(app).post('/api/v1/auth/register').send({});

    expect(response.status).toBe(400);
    expect(response.body.success).toBe(false);
  });

  test('rejects access to the current-user endpoint without a bearer token', async () => {
    const response = await request(app).get('/api/v1/auth/me');

    expect(response.status).toBe(401);
  });

  test('returns a consistent not-found response for unknown API routes', async () => {
    const response = await request(app).get('/api/v1/not-a-route');

    expect(response.status).toBe(404);
    expect(response.body.success).toBe(false);
  });

  test('validates nearby-search coordinates without calling the database', async () => {
    const response = await request(app)
      .get('/api/v1/search/nearby')
      .query({ latitude: '91', longitude: '28' });

    expect(response.status).toBe(400);
    expect(response.body.code).toBe('VALIDATION_ERROR');
  });

  test('supports the provider-search route alias with the same coordinate validation', async () => {
    const response = await request(app)
      .get('/api/v1/providers/search')
      .query({ lat: '91', lng: '28' });

    expect(response.status).toBe(400);
    expect(response.body.code).toBe('VALIDATION_ERROR');
  });
});
