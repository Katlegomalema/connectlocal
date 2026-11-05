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
