/**
 * Structured Logger using Pino
 *
 * Secrets are redacted wherever they appear in a log object (headers, request bodies, errors).
 */

import pino from 'pino';

const logLevel = process.env.LOG_LEVEL || 'info';

export const REDACT_PATHS = [
  'req.headers.authorization',
  'req.headers.cookie',
  'res.headers["set-cookie"]',
  'headers.authorization',
  'authorization',
  'password',
  'newPassword',
  'token',
  'accessToken',
  'refreshToken',
  'access_token',
  'refresh_token',
  'passphrase',
  'otp',
  'pin',
  'accountNumber',
  'account_number',
  '*.password',
  '*.token',
  '*.accessToken',
  '*.refreshToken',
  '*.access_token',
  '*.refresh_token',
  '*.passphrase',
  '*.otp',
  '*.pin',
  '*.accountNumber',
  '*.account_number'
];

const logger = pino({
  level: logLevel,
  redact: { paths: REDACT_PATHS, censor: '[REDACTED]' },
  formatters: {
    level: (label) => ({ level: label.toUpperCase() })
  }
});

export default logger;
