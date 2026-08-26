/**
 * Twilio SMS Integration
 * SMS notifications and OTP
 */

import twilio from 'twilio';
import logger from '../utils/logger.js';
import { ExternalServiceError } from '../utils/errors.js';

const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID;
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN;
const TWILIO_PHONE_NUMBER = process.env.TWILIO_PHONE_NUMBER;

let twilioClient;

if (TWILIO_ACCOUNT_SID && TWILIO_AUTH_TOKEN) {
  twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
}

/**
 * Send SMS
 */
export const sendSms = async (toPhoneNumber, message) => {
  try {
    if (!twilioClient) {
      logger.warn('Twilio not configured - SMS skipped', { to: toPhoneNumber });
      return null;
    }

    const response = await twilioClient.messages.create({
      body: message,
      from: TWILIO_PHONE_NUMBER,
      to: toPhoneNumber
    });

    logger.info('SMS sent', { to: toPhoneNumber, sid: response.sid });
    return response;
  } catch (error) {
    logger.error('Twilio SMS error:', error);
    throw new ExternalServiceError('Failed to send SMS', 'twilio');
  }
};

/**
 * Send OTP SMS
 */
export const sendOtpSms = async (phoneNumber, otp, expiryMinutes = 10) => {
  const message = `Your ConnectLocal verification code is: ${otp}. It expires in ${expiryMinutes} minutes.`;
  return sendSms(phoneNumber, message);
};

/**
 * Send booking notification SMS
 */
export const sendBookingNotificationSms = async (phoneNumber, bookingDetails) => {
  const message = `Your booking for ${bookingDetails.serviceTitle} on ${bookingDetails.date} at ${bookingDetails.time} has been confirmed. Provider: ${bookingDetails.providerName}`;
  return sendSms(phoneNumber, message);
};

/**
 * Send cancellation SMS
 */
export const sendCancellationSms = async (phoneNumber, bookingDetails) => {
  const message = `Your booking for ${bookingDetails.serviceTitle} on ${bookingDetails.date} at ${bookingDetails.time} has been cancelled.`;
  return sendSms(phoneNumber, message);
};

export default {
  sendSms,
  sendOtpSms,
  sendBookingNotificationSms,
  sendCancellationSms
};
