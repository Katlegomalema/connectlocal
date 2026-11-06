/**
 * ConnectLocal Backend - Server Entry Point
 * Starts the Express server on the configured port
 */

import 'dotenv/config';
import app from './src/app.js';
import logger from './src/utils/logger.js';
import { assertCodeSecretConfigured } from './src/utils/secureCodes.js';
import { assertEncryptionKeyConfigured } from './src/utils/encryption.js';
import { startPayoutScheduler } from './src/services/payoutService.js';

// Fail fast: PIN / OTP hashing needs the server secret.
try {
  assertCodeSecretConfigured();
  assertEncryptionKeyConfigured();
} catch (err) {
  logger.fatal(err.message);
  process.exit(1);
}

const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

const server = app.listen(PORT, () => {
  startPayoutScheduler();
  logger.info({
    msg: 'Server started',
    port: PORT,
    environment: NODE_ENV,
    timestamp: new Date().toISOString()
  });
});

// Keep idle connections open longer than the proxies and phones in front of us (Codespaces port forwarding,
// Android's connection pool). Node's default of 5 s closes a connection the app may be about to reuse, so the
// first request after a pause (e.g. a slow password) could fail with "connection closed".
server.keepAliveTimeout = 65000;
server.headersTimeout = 66000; // must be larger than keepAliveTimeout

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    logger.fatal(`Port ${PORT} is already in use. Another server is probably still running `
      + `(stop it with Ctrl+C in its terminal, or: kill $(lsof -t -i:${PORT})), or start on another port: PORT=3001 npm start`);
  } else {
    logger.fatal({ err }, 'Server failed to start');
  }
  process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

export default server;
