import { errorHandler } from '../../src/middleware/errorHandler.js';
import { NotFoundError } from '../../src/utils/errors.js';

const run = (err) => {
  const res = {
    statusCode: 0,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; }
  };
  errorHandler(err, { path: '/x', method: 'GET' }, res, () => {});
  return res;
};

describe('errorHandler', () => {
  test('invalid uuid from Postgres (22P02) is 400, not 500', () => {
    const res = run({ code: '22P02', message: 'invalid input syntax for type uuid: "me"' });
    expect(res.statusCode).toBe(400);
    expect(res.body.code).toBe('INVALID_INPUT');
    expect(res.body.message).not.toContain('syntax'); // raw Postgres text is not returned
  });

  test('unique violation (23505) is 409', () => {
    expect(run({ code: '23505', message: 'duplicate key' }).statusCode).toBe(409);
  });

  test('missing column / function / table is labelled SCHEMA_MISMATCH', () => {
    for (const code of ['42703', 'PGRST202', 'PGRST204', 'PGRST205']) {
      const res = run({ code, message: 'Could not find the function public.search_nearby_providers' });
      expect(res.statusCode).toBe(500);
      expect(res.body.code).toBe('SCHEMA_MISMATCH');
    }
  });

  test('AppError keeps its own status', () => {
    expect(run(new NotFoundError('User not found')).statusCode).toBe(404);
  });

  test('unknown errors are 500', () => {
    expect(run(new Error('boom')).statusCode).toBe(500);
  });
});

describe('errorHandler: request bodies, 404s and logging', () => {
  test('a body that is not valid JSON gives a clean 400 INVALID_JSON (no parser text)', () => {
    const err = Object.assign(new SyntaxError('Expected double-quoted property name in JSON at position 14'), {
      type: 'entity.parse.failed', status: 400
    });
    const res = run(err);
    expect(res.statusCode).toBe(400);
    expect(res.body).toMatchObject({ success: false, code: 'INVALID_JSON', message: 'The request body is not valid JSON' });
  });

  test('a body that is too big gives 413', () => {
    const res = run(Object.assign(new Error('request entity too large'), { type: 'entity.too.large' }));
    expect(res.statusCode).toBe(413);
    expect(res.body.code).toBe('PAYLOAD_TOO_LARGE');
  });

  test('in production a 500 never shows the internal message', () => {
    const before = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    const res = run(new Error('connection string postgres://secret'));
    process.env.NODE_ENV = before;
    expect(res.statusCode).toBe(500);
    expect(res.body.message).toBe('Internal server error');
  });
});

describe('the real app: bad JSON and unknown routes', () => {
  let app;
  let request;
  beforeAll(async () => {
    process.env.CODE_HASH_SECRET = process.env.CODE_HASH_SECRET || 'test-only-secret-test-only-secret-test-only-secret';
    ({ default: request } = await import('supertest'));
    ({ default: app } = await import('../../src/app.js'));
  });

  test('POST with broken JSON -> 400 JSON error', async () => {
    const res = await request(app).post('/api/v1/auth/login').set('Content-Type', 'application/json').send('{"email": "x",');
    expect(res.status).toBe(400);
    expect(res.headers['content-type']).toMatch(/json/);
    expect(res.body.code).toBe('INVALID_JSON');
  });

  test('unknown route -> 404 JSON error', async () => {
    const res = await request(app).get('/api/v1/nope');
    expect(res.status).toBe(404);
    expect(res.body).toMatchObject({ success: false, code: 'NOT_FOUND' });
  });
});
