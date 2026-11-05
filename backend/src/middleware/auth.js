/**
 * Authentication Middleware
 * Verifies JWT tokens and enforces access control
 */

import logger from '../utils/logger.js';
import { AuthenticationError, AuthorizationError, NotFoundError } from '../utils/errors.js';
import { supabase } from '../config/supabase.js';
import * as userRepository from '../repositories/userRepository.js';

const getBearerToken = (header) => {
  if (typeof header !== 'string') return null;
  const [scheme, token, ...extra] = header.trim().split(/\s+/);
  if (scheme?.toLowerCase() !== 'bearer' || !token || extra.length) return null;
  return token;
};

const getActiveProfile = async (authUser) => {
  let profile;
  try {
    profile = await userRepository.getUserById(authUser.id);
  } catch (error) {
    if (error instanceof NotFoundError) throw new AuthenticationError('Account is unavailable');
    throw error;
  }

  if (!profile.is_active || profile.deleted_at) throw new AuthenticationError('Account is not active');
  return {
    id: authUser.id,
    email: authUser.email,
    role: profile.role
  };
};

/**
 * Middleware: Verify JWT token from Authorization header
 */
export const verifyToken = async (req, res, next) => {
  try {
    const token = getBearerToken(req.headers.authorization);

    if (!token) {
      throw new AuthenticationError('No authorization token provided');
    }

    // Verify token with Supabase
    const { data, error } = await supabase.auth.getUser(token);

    if (error || !data.user) {
      throw new AuthenticationError('Invalid or expired token');
    }

    req.user = await getActiveProfile(data.user);

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
    const token = getBearerToken(req.headers.authorization);

    if (token) {
      const { data, error } = await supabase.auth.getUser(token);
      if (!error && data.user) {
        req.user = await getActiveProfile(data.user);
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
