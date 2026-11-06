/**
 * Auth Service
 * Supabase Auth flows and application-profile synchronization
 */

import { supabase, supabaseAdmin } from '../config/supabase.js';
import * as userRepository from '../repositories/userRepository.js';
import * as phoneOtpRepository from '../repositories/phoneOtpRepository.js';
import {
  PHONE_OTP_MAX_ATTEMPTS, PHONE_OTP_MAX_PER_HOUR, PHONE_OTP_TTL_MS
} from '../config/business.js';
import { generateOtp, hashOtp, hashesMatch } from '../utils/secureCodes.js';
import {
  AppError, AuthenticationError, AuthorizationError, ConflictError, NotFoundError, RateLimitError, ValidationError
} from '../utils/errors.js';

/**
 * Load the app profile. If Supabase says the email is confirmed (e.g. the user clicked the email link,
 * which never reaches this API) but the profile does not know yet, sync it: booking needs email_verified.
 */
const profileForAuthUser = async (authUser) => {
  const profile = await userRepository.getUserById(authUser.id);
  if (authUser.email_confirmed_at && !profile.email_verified) {
    return userRepository.updateUser(authUser.id, { email_verified: true });
  }
  return profile;
};

/** Where the confirmation email link lands: EMAIL_REDIRECT_URL, else the first FRONTEND_URL. */
const emailRedirectUrl = () => process.env.EMAIL_REDIRECT_URL
  || (process.env.FRONTEND_URL || '').split(',')[0].trim() || undefined;

/** Turn Supabase Auth errors into the API's status codes (spec: 400 weak password, 409 taken, 429). */
const authError = (error, fallback) => {
  const code = error?.code || '';
  const status = error?.status;
  if (code === 'weak_password') {
    // Supabase Auth has its own password policy (Dashboard -> Auth -> Providers -> Email). Keep it the same as
    // utils/validators.js passwordSchema; if it still asks for a symbol, say that plainly.
    return new ValidationError(/[!@#$%^&*]/.test(error.message || '')
      ? 'Choose a stronger password: add a symbol, for example ! or #.'
      : 'Choose a stronger password.');
  }
 /* if (code === 'over_email_send_rate_limit') {
 return new RateLimitError('We cannot send more confirmation emails right now. Please try again in an hour.');
  }*/
  if (['user_already_exists', 'email_exists'].includes(code)) return new ConflictError('This email is already registered');
  if (code === 'email_not_confirmed') {
    return new AppError('Please confirm your email address first (check your inbox).', 403, 'EMAIL_NOT_CONFIRMED');
  }
  if (code.startsWith('over_') || status === 429) return new RateLimitError();
  if (code === 'email_address_invalid' || code === 'validation_failed') {
    return new ValidationError(error.message || 'Invalid email address');
  }
  return new AuthenticationError(fallback);
};

/**
 * Sign-up. The role ("I need a service" = customer, "I offer a service" = provider) goes in the sign-up
 * metadata; the database trigger handle_new_user creates the public.users row and only ever accepts
 * customer or provider (never admin).
 */
export const registerUser = async (email, password, userData) => {
  if (!['customer', 'provider'].includes(userData.role)) {
    throw new ValidationError('Role must be customer or provider');
  }

  const fullName = (userData.fullName
    ?? `${userData.firstName || ''} ${userData.lastName || ''}`).trim().replace(/\s+/g, ' ');
  if (fullName.length < 2 || fullName.length > 150) {
    throw new ValidationError('Full name must be 2 to 150 characters');
  }

  const redirectTo = emailRedirectUrl();
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { full_name: fullName, role: userData.role },
      ...(redirectTo ? { emailRedirectTo: redirectTo } : {})
    }
  });
  if (error) throw authError(error, 'Registration failed');
  if (!data.user) throw new AuthenticationError('Registration failed');
  // With email confirmation on, Supabase answers an already-registered email with a user that has no
  // identities (and sends nothing).
  if (Array.isArray(data.user.identities) && data.user.identities.length === 0) {
    throw new ConflictError('This email is already registered');
  }

  let profile;
  try {
    profile = await userRepository.getUserById(data.user.id); // created by the trigger
  } catch (lookupError) {
    if (!(lookupError instanceof NotFoundError)) throw lookupError;
    // Trigger missing (e.g. a fresh database): create the row ourselves.
    profile = await userRepository.createUser({
      id: data.user.id,
      email: data.user.email,
      full_name: fullName,
      role: userData.role,
      email_verified: Boolean(data.user.email_confirmed_at),
      phone_verified: false,
      is_active: true
    });
  }
  return { ...data.user, application_profile: profile };
};

export const loginUser = async (email, password) => {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error?.code === 'email_not_confirmed') throw authError(error);
  if (error?.status === 429 || error?.code?.startsWith('over_')) throw authError(error);
  if (error || !data.user || !data.session) throw new AuthenticationError('Invalid email or password');

  const profile = await profileForAuthUser(data.user);
  if (!profile.is_active || profile.deleted_at) throw new AuthorizationError('This account is suspended');
  return { user: profile, session: data.session };
};

/** Resend the sign-up confirmation email. Always answers the same way (no account enumeration). */
export const resendVerificationEmail = async (email) => {
  const redirectTo = emailRedirectUrl();
  const { error } = await supabase.auth.resend({
    type: 'signup',
    email,
    ...(redirectTo ? { options: { emailRedirectTo: redirectTo } } : {})
  });
  if (error && (error.status === 429 || error.code?.startsWith('over_'))) throw new RateLimitError();
  return { sent: true };
};

export const refreshSession = async (refreshToken) => {
  const { data, error } = await supabase.auth.refreshSession({ refresh_token: refreshToken });
  if (error || !data.user || !data.session) throw new AuthenticationError('Unable to refresh session');

  const profile = await profileForAuthUser(data.user);
  if (!profile.is_active || profile.deleted_at) throw new AuthorizationError('This account is suspended');
  return { user: profile, session: data.session };
};

export const verifyUserEmail = async (token) => {
  const { data, error } = await supabase.auth.verifyOtp({ token_hash: token, type: 'email' });
  if (error || !data.user) throw new AuthenticationError('Invalid verification token');
  await userRepository.updateUser(data.user.id, { email_verified: true });
  return data.user;
};

export const sendPasswordResetEmail = async (email) => {
  const redirectTo = process.env.PASSWORD_RESET_REDIRECT_URL;
  const { error } = await supabase.auth.resetPasswordForEmail(email, redirectTo ? { redirectTo } : undefined);
  if (error) throw new AuthenticationError('Unable to request password reset');
  return { success: true };
};

export const updatePasswordWithToken = async (password, token) => {
  const { data, error } = await supabase.auth.verifyOtp({ token_hash: token, type: 'recovery' });
  if (error || !data.user) throw new AuthenticationError('Invalid or expired password reset token');
  const { data: updated, error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
    data.user.id,
    { password }
  );
  if (updateError) throw new AuthenticationError('Unable to update password');
  return updated.user;
};

export const logoutUser = async (accessToken) => {
  if (!accessToken) throw new AuthenticationError('Access token is required');
  const { error } = await supabaseAdmin.auth.admin.signOut(accessToken, 'global');
  if (error) throw new AuthenticationError('Unable to revoke session');
  return { success: true };
};

const E164 = /^\+[1-9]\d{7,14}$/;

/**
 * No paid SMS: the backend generates a 6-digit code (stored only as a hash, valid 5 minutes, 5 tries,
 * single use). Outside production the code is returned in the response so the app can show it
 * (PHONE_OTP_DEV_ECHO); in production a delivery channel must be added before enabling this.
 */
const shouldEchoCode = () => process.env.NODE_ENV !== 'production'
  && (process.env.PHONE_OTP_DEV_ECHO ?? 'true').toLowerCase() === 'true';

export const sendPhoneOtp = async (actor, phone) => {
  if (!actor?.id) throw new AuthenticationError('Authentication required');
  if (typeof phone !== 'string' || !E164.test(phone)) throw new ValidationError('Phone number must use E.164 format');

  const owner = await phoneOtpRepository.findUserByPhone(phone);
  if (owner && owner.id !== actor.id) throw new ConflictError('This phone number belongs to another account');

  const recent = await phoneOtpRepository.countCodesSince(actor.id, new Date(Date.now() - 3600000).toISOString());
  if (recent >= PHONE_OTP_MAX_PER_HOUR) throw new RateLimitError('Too many codes requested. Try again in an hour.');

  const code = generateOtp();
  await phoneOtpRepository.closeOpenCodes(actor.id);
  const created = await phoneOtpRepository.createCode({
    userId: actor.id,
    phoneNumber: phone,
    codeHash: hashOtp(actor.id, phone, code),
    expiresAt: new Date(Date.now() + PHONE_OTP_TTL_MS).toISOString()
  });

  return {
    expiresAt: created.expires_at,
    ...(shouldEchoCode() ? { devCode: code } : {})
  };
};

export const verifyPhoneWithOtp = async (actor, otp) => {
  if (!actor?.id) throw new AuthenticationError('Authentication required');
  if (typeof otp !== 'string' || !/^\d{6}$/.test(otp)) throw new ValidationError('OTP must be 6 digits');

  const open = await phoneOtpRepository.getOpenCode(actor.id);
  if (!open) throw new ValidationError('No active code. Request a new one.');
  if (new Date(open.expires_at).getTime() <= Date.now()) {
    await phoneOtpRepository.consumeCode(open.id);
    throw new ValidationError('The code has expired. Request a new one.');
  }
  if (open.attempts >= PHONE_OTP_MAX_ATTEMPTS) {
    await phoneOtpRepository.consumeCode(open.id);
    throw new ValidationError('Too many wrong codes. Request a new one.');
  }

  // Use up a try BEFORE comparing (conditional on the count we read): of many guesses sent at the same moment
  // only one gets this try, the others are refused, so parallel guessing cannot get around the 5 tries.
  const reserved = await phoneOtpRepository.recordFailedAttempt(open.id, open.attempts);
  if (!reserved) throw new ValidationError('Another check of this code is running. Try again in a moment.');
  if (!hashesMatch(open.code_hash, hashOtp(actor.id, open.phone_number, otp))) {
    const { attempts } = reserved;
    if (attempts >= PHONE_OTP_MAX_ATTEMPTS) await phoneOtpRepository.consumeCode(open.id);
    const left = PHONE_OTP_MAX_ATTEMPTS - attempts;
    throw new ValidationError(left > 0 ? `Wrong code. ${left} tries left.` : 'Wrong code. Request a new one.');
  }

  if (!(await phoneOtpRepository.consumeCode(open.id))) throw new ValidationError('This code was already used');
  await userRepository.updateUser(actor.id, { phone_number: open.phone_number, phone_verified: true });
  return { id: actor.id, phone: open.phone_number, phoneVerified: true };
};

export default {
  registerUser,
  resendVerificationEmail,
  loginUser,
  refreshSession,
  verifyUserEmail,
  sendPasswordResetEmail,
  updatePasswordWithToken,
  logoutUser,
  sendPhoneOtp,
  verifyPhoneWithOtp
};
