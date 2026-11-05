/**
 * SendGrid Email Integration
 * Email notifications and transactional emails
 */

import sgMail from '@sendgrid/mail';
import logger from '../utils/logger.js';
import { ExternalServiceError } from '../utils/errors.js';

const { SENDGRID_API_KEY } = process.env;
const FROM_EMAIL = process.env.FROM_EMAIL || 'noreply@connectlocal.app';

if (SENDGRID_API_KEY) {
  sgMail.setApiKey(SENDGRID_API_KEY);
}

/**
 * Send email
 */
export const sendEmail = async (to, subject, htmlContent, textContent) => {
  try {
    if (!SENDGRID_API_KEY) {
      logger.warn('SendGrid not configured - email skipped', { to, subject });
      return null;
    }

    const msg = {
      to,
      from: FROM_EMAIL,
      subject,
      text: textContent,
      html: htmlContent
    };

    const response = await sgMail.send(msg);
    logger.info('Email sent', { to, subject, messageId: response[0].headers['x-message-id'] });

    return response;
  } catch (error) {
    logger.error('SendGrid email error:', error);
    throw new ExternalServiceError('Failed to send email', 'sendgrid');
  }
};

/**
 * Send welcome email
 */
export const sendWelcomeEmail = async (email, name) => {
  const subject = 'Welcome to ConnectLocal';
  const htmlContent = `
    <h1>Welcome to ConnectLocal!</h1>
    <p>Hi ${name},</p>
    <p>Thank you for joining our platform.</p>
    <p>You can now search for local service providers in your area.</p>
  `;

  return sendEmail(email, subject, htmlContent, htmlContent);
};

/**
 * Send booking confirmation email
 */
export const sendBookingConfirmationEmail = async (email, bookingDetails) => {
  const subject = `Booking Confirmed - ${bookingDetails.serviceTitle}`;
  const htmlContent = `
    <h1>Booking Confirmed</h1>
    <p>Your booking has been confirmed.</p>
    <p><strong>Service:</strong> ${bookingDetails.serviceTitle}</p>
    <p><strong>Date:</strong> ${bookingDetails.date}</p>
    <p><strong>Time:</strong> ${bookingDetails.time}</p>
    <p><strong>Provider:</strong> ${bookingDetails.providerName}</p>
  `;

  return sendEmail(email, subject, htmlContent, htmlContent);
};

/**
 * Send password reset email
 */
export const sendPasswordResetEmail = async (email, resetLink) => {
  const subject = 'Reset Your Password';
  const htmlContent = `
    <h1>Password Reset</h1>
    <p>Click the link below to reset your password:</p>
    <a href="${resetLink}">Reset Password</a>
    <p>This link expires in 24 hours.</p>
  `;

  return sendEmail(email, subject, htmlContent, htmlContent);
};

/**
 * Send verification email
 */
export const sendVerificationEmail = async (email, verificationLink) => {
  const subject = 'Verify Your Email Address';
  const htmlContent = `
    <h1>Email Verification</h1>
    <p>Click the link below to verify your email:</p>
    <a href="${verificationLink}">Verify Email</a>
    <p>This link expires in 24 hours.</p>
  `;

  return sendEmail(email, subject, htmlContent, htmlContent);
};

export default {
  sendEmail,
  sendWelcomeEmail,
  sendBookingConfirmationEmail,
  sendPasswordResetEmail,
  sendVerificationEmail
};
