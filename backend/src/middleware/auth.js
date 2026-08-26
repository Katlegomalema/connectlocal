/**
 * Authentication Middleware
 * Verifies JWT tokens and enforces access control
 */

import jwt from 'jsonwebtoken';
import logger from '../utils/logger.js';
import { AuthenticationError, AuthorizationError } from '../utils/errors.js';
import { supabase } from '../config/supabase.js';

/**
 * Middleware: Verify JWT token from Authorization header
 */
export const verifyToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];

    if (!token) {
      throw new AuthenticationError('No authorization token provided');
    }

    // Verify token with Supabase
    const { data, error } = await supabase.auth.getUser(token);

    if (error || !data.user) {
      throw new AuthenticationError('Invalid or expired token');
    }

    req.user = {
      id: data.user.id,
      email: data.user.email,
      role: data.user.user_metadata?.role || 'customer'
    };

    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Middleware: Require specific role
 */
export const requireRole = (...allowedRoles) => (req, res, next) => {
  if (!req.user) {
    return next(new AuthenticationError('Authentication required'));
  }

  if (!allowedRoles.includes(req.user.role)) {
    return next(new AuthorizationError(
      `This action requires one of the following roles: ${allowedRoles.join(', ')}`
    ));
  }

  next();
};

/**
 * Middleware: Optional token verification
 * Does not throw if token is missing, but verifies if present
 */
export const optionalToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];

    if (token) {
      const { data } = await supabase.auth.getUser(token);
      if (data.user) {
        req.user = {
          id: data.user.id,
          email: data.user.email,
          role: data.user.user_metadata?.role || 'customer'
        };
      }
    }

    next();
  } catch (error) {
    logger.warn('Optional token verification failed:', error.message);
    next();
  }
};

/**
 * Middleware: Verify user owns the resource
 */
export const requireOwnership = (paramName = 'id') => (req, res, next) => {
  if (!req.user) {
    return next(new AuthenticationError('Authentication required'));
  }

  const resourceId = req.params[paramName];
  if (req.user.id !== resourceId && req.user.role !== 'admin') {
    return next(new AuthorizationError('You do not have permission to access this resource'));
  }

  next();
};
