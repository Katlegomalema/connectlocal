/**
 * Error Handling Middleware
 * Centralized error handling for the application
 */

import logger from '../utils/logger.js';
import { AppError } from '../utils/errors.js';

/**
 * Main error handler middleware
 * Should be placed last in middleware stack
 */
export const errorHandler = (err, req, res, _next) => {
  logger.error({
    msg: 'Error caught by error handler',
    error: err.message,
    code: err.code,
    statusCode: err.statusCode,
    stack: err.stack,
    path: req.path,
    method: req.method
  });

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
    const errors = err.errors.map(e => ({
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
