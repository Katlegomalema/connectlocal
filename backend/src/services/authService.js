/**
 * Auth Service
 * Supabase Auth flows and application-profile synchronization
 */

import { supabase, supabaseAdmin } from '../config/supabase.js';
import * as userRepository from '../repositories/userRepository.js';
import { AuthenticationError, ValidationError } from '../utils/errors.js';

const profileForAuthUser = (authUser) => userRepository.getUserById(authUser.id);

export const registerUser = async (email, password, userData) => {
  if (!['customer', 'provider'].includes(userData.role)) {
    throw new ValidationError('Role must be customer or provider');
  }

  const fullName = `${userData.firstName || ''} ${userData.lastName || ''}`.trim();
  if (fullName.length < 2 || fullName.length > 150) {
    throw new ValidationError('A valid first and last name are required');
  }

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { full_name: fullName } }
  });
  if (error) throw new AuthenticationError(error.message);
  if (!data.user) throw new AuthenticationError('User registration failed');

  try {
    const profile = await userRepository.createUser({
      id: data.user.id,
      email: data.user.email,
      full_name: fullName,
      phone_number: userData.phone || null,
      role: userData.role,
        email_verified: Boolean(data.user.email_confirmed_at),
        phone_verified: false,
        is_active: true
    });
    return { ...data.user, application_profile: profile };
  } catch (profileError) {
    await supabaseAdmin.auth.admin.deleteUser(data.user.id);
    throw profileError;
  }
};

export const loginUser = async (email, password) => {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error || !data.user || !data.session) throw new AuthenticationError('Invalid email or password');

  const profile = await profileForAuthUser(data.user);
    if (!profile.is_active || profile.deleted_at) throw new AuthenticationError('This account is not active');
  return { user: profile, session: data.session };
};

export const refreshSession = async (refreshToken) => {
  const { data, error } = await supabase.auth.refreshSession({ refresh_token: refreshToken });
  if (error || !data.user || !data.session) throw new AuthenticationError('Unable to refresh session');

  const profile = await profileForAuthUser(data.user);
    if (!profile.is_active || profile.deleted_at) throw new AuthenticationError('This account is not active');
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

export const sendPhoneOtp = async (phone) => {
  const { error } = await supabase.auth.signInWithOtp({
    phone,
    options: { shouldCreateUser: false }
  });
  if (error) throw new AuthenticationError('Unable to send phone verification code');
  return { success: true };
};

export const verifyPhoneWithOtp = async (phone, otp) => {
  const { data, error } = await supabase.auth.verifyOtp({ phone, token: otp, type: 'sms' });
  if (error || !data.user) throw new AuthenticationError('Invalid phone verification code');
    await userRepository.updateUser(data.user.id, { phone_number: phone, phone_verified: true });
  return data.user;
};

export default {
  registerUser,
  loginUser,
  refreshSession,
  verifyUserEmail,
  sendPasswordResetEmail,
  updatePasswordWithToken,
  logoutUser,
  sendPhoneOtp,
  verifyPhoneWithOtp
};
