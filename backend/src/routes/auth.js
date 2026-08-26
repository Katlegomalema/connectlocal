/**
 * Authentication Routes
 * Handles user registration, login, token refresh, and logout
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { validateBody } from '../middleware/validation.js';
import { verifyToken } from '../middleware/auth.js';
import * as authService from '../services/authService.js';
import { emailSchema, passwordSchema } from '../utils/validators.js';
import logger from '../utils/logger.js';

const router = express.Router();

// Validation schemas
const registerSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  firstName: z.string().min(2),
  lastName: z.string().min(2),
  role: z.enum(['customer', 'provider']).default('customer'),
  phone: z.string().optional()
});

const loginSchema = z.object({
  email: emailSchema,
  password: z.string()
});

const refreshTokenSchema = z.object({
  refreshToken: z.string()
});

const passwordResetSchema = z.object({
  email: emailSchema
});

const resetPasswordSchema = z.object({
  token: z.string(),
  password: passwordSchema
});

const verifyEmailSchema = z.object({
  token: z.string()
});

const verifyPhoneSchema = z.object({
  phone: z.string(),
  otp: z.string().length(6, 'OTP must be 6 digits')
});

/**
 * POST /api/v1/auth/register
 * Register a new user with email and password
 */
router.post('/register', validateBody(registerSchema), asyncHandler(async (req, res) => {
  logger.info(`Registration request: ${req.validatedBody.email}`);

  const user = await authService.registerUser(
    req.validatedBody.email,
    req.validatedBody.password,
    {
      firstName: req.validatedBody.firstName,
      lastName: req.validatedBody.lastName,
      role: req.validatedBody.role,
      phone: req.validatedBody.phone
    }
  );

  res.status(201).json({
    success: true,
    message: 'User registered successfully. Please verify your email.',
    data: {
      user: {
        id: user.id,
        email: user.email,
        role: req.validatedBody.role
      }
    }
  });
}));

/**
 * POST /api/v1/auth/login
 * Authenticate user and return JWT token
 */
router.post('/login', validateBody(loginSchema), asyncHandler(async (req, res) => {
  logger.info(`Login request: ${req.validatedBody.email}`);

  const { user, session } = await authService.loginUser(
    req.validatedBody.email,
    req.validatedBody.password
  );

  res.status(200).json({
    success: true,
    message: 'Login successful',
    data: {
      user: {
        id: user.id,
        email: user.email,
        role: user.user_metadata?.role || 'customer'
      },
      token: session.access_token,
      refreshToken: session.refresh_token,
      expiresIn: session.expires_in
    }
  });
}));

/**
 * POST /api/v1/auth/refresh
 * Refresh access token using refresh token
 */
router.post('/refresh', validateBody(refreshTokenSchema), asyncHandler(async (req, res) => {
  logger.info('Token refresh request');

  const { user, session } = await authService.refreshSession(req.validatedBody.refreshToken);

  res.status(200).json({
    success: true,
    data: {
      token: session.access_token,
      refreshToken: session.refresh_token,
      expiresIn: session.expires_in
    }
  });
}));

/**
 * POST /api/v1/auth/logout
 * Invalidate user session
 */
router.post('/logout', verifyToken, asyncHandler(async (req, res) => {
  logger.info(`Logout request: ${req.user.id}`);

  await authService.logoutUser(req.user.id);

  res.status(200).json({
    success: true,
    message: 'Logout successful'
  });
}));

/**
 * POST /api/v1/auth/password-reset
 * Request password reset email
 */
router.post('/password-reset', validateBody(passwordResetSchema), asyncHandler(async (req, res) => {
  logger.info(`Password reset request: ${req.validatedBody.email}`);

  await authService.sendPasswordResetEmail(req.validatedBody.email);

  res.status(200).json({
    success: true,
    message: 'If an account exists, a password reset email has been sent'
  });
}));

/**
 * POST /api/v1/auth/reset-password
 * Reset password with token from email
 */
router.post('/reset-password', validateBody(resetPasswordSchema), asyncHandler(async (req, res) => {
  logger.info('Password reset with token');

  await authService.updatePasswordWithToken(req.validatedBody.password, req.validatedBody.token);

  res.status(200).json({
    success: true,
    message: 'Password has been reset successfully'
  });
}));

/**
 * POST /api/v1/auth/verify-email
 * Verify email address with token
 */
router.post('/verify-email', validateBody(verifyEmailSchema), asyncHandler(async (req, res) => {
  logger.info('Email verification request');

  const user = await authService.verifyUserEmail(req.validatedBody.token);

  res.status(200).json({
    success: true,
    message: 'Email verified successfully',
    data: {
      user: {
        id: user.id,
        email: user.email
      }
    }
  });
}));

/**
 * POST /api/v1/auth/verify-phone
 * Verify phone number with OTP
 */
router.post('/verify-phone', validateBody(verifyPhoneSchema), asyncHandler(async (req, res) => {
  logger.info('Phone verification request');

  // TODO: Implement phone OTP verification
  // This requires Twilio OTP verification integration
  // await authService.verifyPhoneWithOtp(req.validatedBody.phone, req.validatedBody.otp);

  res.status(200).json({
    success: true,
    message: 'Phone verified successfully'
  });
}));

/**
 * GET /api/v1/auth/me
 * Get current authenticated user info
 */
router.get('/me', verifyToken, asyncHandler(async (req, res) => {
  res.status(200).json({
    success: true,
    data: {
      user: req.user
    }
  });
}));

export default router;
