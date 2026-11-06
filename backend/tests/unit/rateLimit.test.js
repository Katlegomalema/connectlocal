import express from 'express';
import request from 'supertest';
import { rateLimit } from '../../src/middleware/rateLimit.js';
import { errorHandler } from '../../src/middleware/errorHandler.js';

describe('rate limits', () => {
  test('after the limit: 429 with Retry-After and a clear message; other keys are not affected', async () => {
    const app = express();
    app.use(express.json());
    app.post('/login', rateLimit({
      name: 't', windowMs: 60000, max: 3, key: (req) => req.body.email, message: 'Too many sign-in attempts.'
    }), (req, res) => res.json({ ok: true }));
    app.use(errorHandler);
    for (let i = 0; i < 3; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      expect((await request(app).post('/login').send({ email: 'a@x.co' })).status).toBe(200);
    }
    const blocked = await request(app).post('/login').send({ email: 'a@x.co' });
    expect(blocked.status).toBe(429);
    expect(blocked.headers['retry-after']).toBeDefined();
    expect(blocked.body).toMatchObject({ code: 'RATE_LIMITED', message: 'Too many sign-in attempts.' });
    expect((await request(app).post('/login').send({ email: 'b@x.co' })).status).toBe(200);
  });
});
