/**
 * Structured Logger using Pino
 * Provides consistent logging across the application
 */

import pino from 'pino';

const logLevel = process.env.LOG_LEVEL || 'info';

const logger = pino({
  level: logLevel,
  transport: {
    target: 'pino-pretty',
    options: {
      colorize: true,
      translateTime: 'SYS:standard',
      ignore: 'pid,hostname',
      singleLine: false
    }
  },
  formatters: {
    level: (label) => {
      return { level: label.toUpperCase() };
    }
  }
});

export default logger;
