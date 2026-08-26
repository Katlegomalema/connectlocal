/**
 * Request Validation Middleware
 * Validates incoming requests using Zod schemas
 */

import logger from '../utils/logger.js';
import { ValidationError } from '../utils/errors.js';

/**
 * Middleware factory: Validate request body against schema
 */
export const validateBody = (schema) => async (req, res, next) => {
  try {
    const validated = await schema.parseAsync(req.body);
    req.validatedBody = validated;
    next();
  } catch (error) {
    logger.warn({
      msg: 'Body validation failed',
      errors: error.errors,
      path: req.path
    });

    const formattedErrors = error.errors.map(e => ({
      field: e.path.join('.') || 'root',
      message: e.message
    }));

    next(new ValidationError('Request validation failed', formattedErrors));
  }
};

/**
 * Middleware factory: Validate query parameters against schema
 */
export const validateQuery = (schema) => async (req, res, next) => {
  try {
    const validated = await schema.parseAsync(req.query);
    req.validatedQuery = validated;
    next();
  } catch (error) {
    logger.warn({
      msg: 'Query validation failed',
      errors: error.errors,
      path: req.path
    });

    const formattedErrors = error.errors.map(e => ({
      field: e.path.join('.') || 'root',
      message: e.message
    }));

    next(new ValidationError('Query validation failed', formattedErrors));
  }
};

/**
 * Middleware factory: Validate path parameters against schema
 */
export const validateParams = (schema) => async (req, res, next) => {
  try {
    const validated = await schema.parseAsync(req.params);
    req.validatedParams = validated;
    next();
  } catch (error) {
    logger.warn({
      msg: 'Params validation failed',
      errors: error.errors,
      path: req.path
    });

    const formattedErrors = error.errors.map(e => ({
      field: e.path.join('.') || 'root',
      message: e.message
    }));

    next(new ValidationError('Parameter validation failed', formattedErrors));
  }
};
