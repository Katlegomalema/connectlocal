/**
 * Error Handling Middleware
 * Centralized error handling for the application
 */

import logger from '../utils/logger.js';
import { AppError } from '../utils/errors.js';

/**
 * Postgres / PostgREST error codes -> HTTP status.
 * Client mistakes become 4xx; "schema not migrated" stays 500 but is labelled so it is easy to spot.
 */
const SCHEMA_MISMATCH = [500, 'SCHEMA_MISMATCH', 'Database schema is out of date (run the migrations)'];
const DB_ERRORS = {
  '22P02': [400, 'INVALID_INPUT', 'Invalid ID or value format'],
  22007: [400, 'INVALID_INPUT', 'Invalid date or time format'],
  22003: [400, 'INVALID_INPUT', 'Number out of range'],
  23502: [400, 'MISSING_FIELD', 'A required field is missing'],
  23503: [409, 'INVALID_REFERENCE', 'A referenced record does not exist or is still in use'],
  23505: [409, 'CONFLICT', 'This record already exists'],
  23514: [400, 'CONSTRAINT_VIOLATION', 'A value is not allowed'],
  PGRST116: [404, 'NOT_FOUND', 'Record not found'],
  42703: SCHEMA_MISMATCH, // undefined column
  '42P01': SCHEMA_MISMATCH, // undefined table
  42883: SCHEMA_MISMATCH, // undefined function
  PGRST202: SCHEMA_MISMATCH, // function not in schema cache
  PGRST204: SCHEMA_MISMATCH, // column not in schema cache
  PGRST205: SCHEMA_MISMATCH // table not in schema cache
};

const statusFor = (err) => {
  if (err instanceof AppError) return err.statusCode;
  if (typeof err.code === 'string' && DB_ERRORS[err.code]) return DB_ERRORS[err.code][0];
  return err.statusCode || 500;
};

/**
 * Main error handler middleware
 * Should be placed last in middleware stack
 */
export const errorHandler = (err, req, res, _next) => {
  const status = statusFor(err);
  const logEntry = {
    msg: 'Error caught by error handler',
    error: err.message,
    code: err.code,
    statusCode: status,
    path: req.path,
    method: req.method
  };
  // Stack traces only for real server errors; client errors (4xx) are a one-line warning.
  if (status >= 500) logger.error({ ...logEntry, stack: err.stack });
  else logger.warn(logEntry);

  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      code: err.code,
      message: err.message,
      errors: err.errors || [],
      timestamp: err.timestamp
    });
  }

  // Handle Zod validation errors
  if (err.name === 'ZodError') {
    const errors = err.errors.map((e) => ({
      field: e.path.join('.'),
      message: e.message
    }));
    return res.status(400).json({
      success: false,
      code: 'VALIDATION_ERROR',
      message: 'Validation failed',
      errors,
      timestamp: new Date().toISOString()
    });
  }

  // Handle JWT errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      success: false,
      code: 'INVALID_TOKEN',
      message: 'Invalid or expired token',
      timestamp: new Date().toISOString()
    });
  }

  // Postgres / PostgREST errors (from supabase-js)
  const dbError = typeof err.code === 'string' ? DB_ERRORS[err.code] : undefined;
  if (dbError) {
    const [dbStatus, code, message] = dbError;
    return res.status(dbStatus).json({
      success: false,
      code,
      // Outside production, schema problems show the real Postgres message to help debugging.
      message: code === 'SCHEMA_MISMATCH' && process.env.NODE_ENV !== 'production'
        ? `${message}: ${err.message}`
        : message,
      timestamp: new Date().toISOString()
    });
  }

  // Generic error response
  res.status(err.statusCode || 500).json({
    success: false,
    code: err.code || 'INTERNAL_ERROR',
    message: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message,
    timestamp: new Date().toISOString()
  });
};

/**
 * 404 Not Found handler
 */
export const notFoundHandler = (req, res) => {
  res.status(404).json({
    success: false,
    code: 'NOT_FOUND',
    message: `Route ${req.method} ${req.path} not found`,
    timestamp: new Date().toISOString()
  });
};

/**
 * Async error wrapper for route handlers
 * Wraps async functions to catch errors and pass to error handler
 */
export const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};
