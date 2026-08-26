/**
 * Auth Service
 * Wraps Supabase auth operations and business logic
 */

import { supabase } from '../config/supabase.js';
import logger from '../utils/logger.js';
import { AuthenticationError, ValidationError } from '../utils/errors.js';

/**
 * Register user with email and password
 */
export const registerUser = async (email, password, userData) => {
  try {
    logger.info(`Registering user: ${email}`);

    // Sign up with Supabase Auth
    const { data, error } = await supabase.auth.signUpWithPassword({
      email,
      password,
      options: {
        data: userData
      }
    });

    if (error) {
      throw new AuthenticationError(error.message);
    }

    // Create user profile in database
    // await createUserProfile(data.user.id, userData);

    return data.user;
  } catch (error) {
    logger.error('User registration error:', error);
    throw error;
  }
};

/**
 * Login user with email and password
 */
export const loginUser = async (email, password) => {
  try {
    logger.info(`Attempting login for: ${email}`);

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      throw new AuthenticationError('Invalid email or password');
    }

    return {
      user: data.user,
      session: data.session
    };
  } catch (error) {
    logger.error('Login error:', error);
    throw error;
  }
};

/**
 * Refresh session
 */
export const refreshSession = async (refreshToken) => {
  try {
    logger.info('Refreshing session');

    const { data, error } = await supabase.auth.refreshSession({
      refresh_token: refreshToken
    });

    if (error) {
      throw new AuthenticationError('Unable to refresh session');
    }

    return {
      user: data.user,
      session: data.session
    };
  } catch (error) {
    logger.error('Session refresh error:', error);
    throw error;
  }
};

/**
 * Verify email
 */
export const verifyUserEmail = async (token) => {
  try {
    logger.info('Verifying email');

    const { data, error } = await supabase.auth.verifyOtp({
      token_hash: token,
      type: 'email'
    });

    if (error) {
      throw new AuthenticationError('Invalid verification token');
    }

    return data.user;
  } catch (error) {
    logger.error('Email verification error:', error);
    throw error;
  }
};

/**
 * Send password reset email
 */
export const sendPasswordResetEmail = async (email) => {
  try {
    logger.info(`Sending password reset email to: ${email}`);

    const { error } = await supabase.auth.resetPasswordForEmail(email);

    if (error) {
      throw new AuthenticationError(error.message);
    }

    return { success: true };
  } catch (error) {
    logger.error('Password reset email error:', error);
    throw error;
  }
};

/**
 * Update password with reset token
 */
export const updatePasswordWithToken = async (password, token) => {
  try {
    logger.info('Updating password with token');

    const { data, error } = await supabase.auth.updateUser({
      password,
      nonce: token
    });

    if (error) {
      throw new AuthenticationError(error.message);
    }

    return data.user;
  } catch (error) {
    logger.error('Password update error:', error);
    throw error;
  }
};

/**
 * Logout user
 */
export const logoutUser = async (userId) => {
  try {
    logger.info(`Logging out user: ${userId}`);

    const { error } = await supabase.auth.signOut();

    if (error) {
      throw new AuthenticationError(error.message);
    }

    return { success: true };
  } catch (error) {
    logger.error('Logout error:', error);
    throw error;
  }
};

/**
 * Verify phone with OTP
 */
export const verifyPhoneWithOtp = async (phone, otp) => {
  try {
    logger.info(`Verifying phone: ${phone}`);

    const { data, error } = await supabase.auth.verifyOtp({
      phone,
      token: otp,
      type: 'sms'
    });

    if (error) {
      throw new AuthenticationError(error.message);
    }

    return data.user;
  } catch (error) {
    logger.error('Phone verification error:', error);
    throw error;
  }
};

export default {
  registerUser,
  loginUser,
  refreshSession,
  verifyUserEmail,
  sendPasswordResetEmail,
  updatePasswordWithToken,
  logoutUser,
  verifyPhoneWithOtp
};
