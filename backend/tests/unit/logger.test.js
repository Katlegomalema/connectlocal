import { Writable } from 'node:stream';
import pino from 'pino';
import { REDACT_PATHS } from '../../src/utils/logger.js';

const capture = () => {
  const lines = [];
  const stream = new Writable({
    write(chunk, _enc, cb) { lines.push(chunk.toString()); cb(); }
  });
  return { log: pino({ redact: { paths: REDACT_PATHS, censor: '[REDACTED]' } }, stream), lines };
};

describe('logger redaction', () => {
  test('hides tokens, cookies, passwords and PINs', () => {
    const { log, lines } = capture();
    log.info({
      req: { headers: { authorization: 'Bearer secret-jwt', cookie: 'sid=abc' } },
      body: { password: 'hunter2', pin: '1234', email: 'a@b.test' },
      refreshToken: 'secret-refresh'
    }, 'test');
    const out = lines.join('');
    ['secret-jwt', 'sid=abc', 'hunter2', '1234', 'secret-refresh'].forEach((secret) => {
      expect(out).not.toContain(secret);
    });
    expect(out).toContain('a@b.test');
  });
});
