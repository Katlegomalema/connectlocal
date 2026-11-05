/**
 * Authentication Routes (docs/api-specs/Authentication-API.md)
 *
 *   POST /register                  { email, password, fullName, role }      -> 201
 *   POST /login                     { email, password }                      -> tokens + user
 *   POST /refresh                   { refreshToken }                         -> new tokens
 *   POST /logout                    (signed in)                              -> { loggedOut }
 *   GET  /me                        (signed in)                              -> own profile
 *   POST /verify-email              { token }
 *   POST /resend-verification       { email }
 *   POST /phone/request-otp         (signed in) { phoneNumber }              -> { otpSent, expiresInSeconds }
 *   POST /phone/verify-otp          (signed in) { otp }                      -> { phoneVerified }
 *   POST /password-reset, /reset-password
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { validateBody } from '../middleware/validation.js';
import { verifyToken } from '../middleware/auth.js';
import * as authService from '../services/authService.js';
import * as userService from '../services/userService.js';
import { PHONE_OTP_TTL_MS } from '../config/business.js';
import { emailSchema, passwordSchema, phoneSchema } from '../utils/validators.js';

const router = express.Router();

// ---- schemas --------------------------------------------------------------------------------------------
const registerSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  fullName: z.string().trim().min(2).max(150)
    .optional(),
  // Older clients send first/last name separately.
  firstName: z.string().trim().min(1).max(75)
    .optional(),
  lastName: z.string().trim().min(1).max(75)
    .optional(),
  // "I need a service" = customer, "I offer a service" = provider. Never admin.
  role: z.enum(['customer', 'provider']).default('customer')
}).refine((body) => body.fullName || (body.firstName && body.lastName), {
  message: 'fullName is required',
  path: ['fullName']
});

const loginSchema = z.object({ email: emailSchema, password: z.string().min(1) });
const refreshTokenSchema = z.object({ refreshToken: z.string().min(1) });
const emailOnlySchema = z.object({ email: emailSchema });
const resetPasswordSchema = z.object({ token: z.string().min(1), password: passwordSchema });
const verifyEmailSchema = z.object({ token: z.string().min(1) });
const requestOtpSchema = z.object({
  phoneNumber: phoneSchema.optional(),
  phone: phoneSchema.optional() // older name
}).refine((body) => body.phoneNumber || body.phone, { message: 'phoneNumber is required', path: ['phoneNumber'] });
const verifyOtpSchema = z.object({
  otp: z.string().regex(/^\d{6}$/, 'The code must be 6 digits'),
  // Ignored: the number is the one the code was sent to.
  phoneNumber: z.string().optional(),
  phone: z.string().optional()
});

// ---- response shapes -------------------------------------------------------------------------------------
const userSummary = (profile) => {
  const emailVerified = Boolean(profile.email_verified);
  const phoneVerified = Boolean(profile.phone_verified);
  return {
    id: profile.id,
    email: profile.email,
    fullName: profile.full_name ?? null,
    role: profile.role, // from public.users, never from user-editable metadata
    emailVerified,
    phoneVerified,
    phoneNumber: profile.phone_number ?? null,
    isVerified: emailVerified && phoneVerified
  };
};

const tokens = (session) => ({
  accessToken: session.access_token,
  refreshToken: session.refresh_token, // Supabase rotates refresh tokens: always store the new one
  expiresIn: session.expires_in,
  expiresAt: session.expires_at
});

const noStore = (res) => res.set('Cache-Control', 'no-store');

// ---- routes ----------------------------------------------------------------------------------------------
router.post('/register', validateBody(registerSchema), asyncHandler(async (req, res) => {
  const body = req.validatedBody;
  const user = await authService.registerUser(body.email, body.password, {
    fullName: body.fullName,
    firstName: body.firstName,
    lastName: body.lastName,
    role: body.role
  });
  const profile = user.application_profile;

  res.status(201).json({
    success: true,
    message: 'Account created. Please confirm your email address.',
    data: {
      userId: user.id,
      email: user.email,
      role: profile.role,
      emailVerified: Boolean(profile.email_verified),
      isVerified: false
    }
  });
}));

router.post('/login', validateBody(loginSchema), asyncHandler(async (req, res) => {
  const { user, session } = await authService.loginUser(req.validatedBody.email, req.validatedBody.password);
  noStore(res);
  res.status(200).json({
    success: true,
    data: { ...tokens(session), user: userSummary(user) }
  });
}));

router.post('/refresh', validateBody(refreshTokenSchema), asyncHandler(async (req, res) => {
  const { user, session } = await authService.refreshSession(req.validatedBody.refreshToken);
  noStore(res);
  res.status(200).json({
    success: true,
    data: { ...tokens(session), user: userSummary(user) }
  });
}));

router.post('/logout', verifyToken, asyncHandler(async (req, res) => {
  const accessToken = req.headers.authorization?.split(' ')[1];
  await authService.logoutUser(accessToken);
  res.status(200).json({ success: true, data: { loggedOut: true } });
}));

router.get('/me', verifyToken, asyncHandler(async (req, res) => {
  const user = await userService.getOwnProfile(req.user);
  noStore(res);
  res.status(200).json({ success: true, data: { user } });
}));

router.post('/verify-email', validateBody(verifyEmailSchema), asyncHandler(async (req, res) => {
  await authService.verifyUserEmail(req.validatedBody.token);
  res.status(200).json({ success: true, data: { isVerified: true, emailVerified: true } });
}));

router.post('/resend-verification', validateBody(emailOnlySchema), asyncHandler(async (req, res) => {
  await authService.resendVerificationEmail(req.validatedBody.email);
  // Same answer whether or not the account exists.
  res.status(200).json({
    success: true,
    message: 'If the account exists and is not confirmed yet, a new email has been sent.',
    data: { sent: true }
  });
}));

const requestOtp = asyncHandler(async (req, res) => {
  const phone = req.validatedBody.phoneNumber || req.validatedBody.phone;
  const result = await authService.sendPhoneOtp(req.user, phone);
  noStore(res);
  res.status(200).json({
    success: true,
    data: {
      otpSent: true,
      expiresInSeconds: PHONE_OTP_TTL_MS / 1000,
      expiresAt: result.expiresAt,
      // Only outside production (no paid SMS): the app shows the code like an SMS.
      ...(result.devCode ? { devCode: result.devCode } : {})
    }
  });
});

const verifyOtp = asyncHandler(async (req, res) => {
  const result = await authService.verifyPhoneWithOtp(req.user, req.validatedBody.otp);
  res.status(200).json({
    success: true,
    data: { phoneVerified: true, phoneNumber: result.phone }
  });
});

router.post('/phone/request-otp', verifyToken, validateBody(requestOtpSchema), requestOtp);
router.post('/phone/verify-otp', verifyToken, validateBody(verifyOtpSchema), verifyOtp);
// Older paths, kept as aliases.
router.post('/phone/otp', verifyToken, validateBody(requestOtpSchema), requestOtp);
router.post('/verify-phone', verifyToken, validateBody(verifyOtpSchema), verifyOtp);

router.post('/password-reset', validateBody(emailOnlySchema), asyncHandler(async (req, res) => {
  await authService.sendPasswordResetEmail(req.validatedBody.email);
  res.status(200).json({
    success: true,
    message: 'If an account exists, a password reset email has been sent'
  });
}));

router.post('/reset-password', validateBody(resetPasswordSchema), asyncHandler(async (req, res) => {
  await authService.updatePasswordWithToken(req.validatedBody.password, req.validatedBody.token);
  res.status(200).json({ success: true, message: 'Password has been reset successfully' });
}));

export default router;
