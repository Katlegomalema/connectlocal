/**
 * PayFast Payment Gateway Integration
 * South African payment processing
 */

import axios from 'axios';
import crypto from 'crypto';
import { URLSearchParams } from 'url';
import logger from '../utils/logger.js';
import { ExternalServiceError } from '../utils/errors.js';

const { PAYFAST_MERCHANT_ID } = process.env;
const { PAYFAST_MERCHANT_KEY } = process.env;
const { PAYFAST_API_KEY } = process.env;
const { PAYFAST_PASSPHRASE } = process.env;

const SANDBOX_URL = 'https://sandbox.payfast.co.za';
const LIVE_URL = 'https://www.payfast.co.za';
const API_URL = process.env.NODE_ENV === 'production' ? LIVE_URL : SANDBOX_URL;
const VALIDATION_URL = `${API_URL}/eng/query/validate`;

const assertPayFastConfig = () => {
  if (!PAYFAST_MERCHANT_ID || !PAYFAST_MERCHANT_KEY || !PAYFAST_PASSPHRASE) {
    throw new ExternalServiceError('PayFast merchant configuration is missing', 'payfast');
  }
};

const encodePayFastValue = (value) => encodeURIComponent(String(value).trim()).replace(/%20/g, '+');

const generateSignature = (payload) => {
  const fields = Object.entries(payload)
    .filter(([key, value]) => key !== 'signature' && value !== undefined && value !== null && value !== '')
    .map(([key, value]) => `${key}=${encodePayFastValue(value)}`);

  if (PAYFAST_PASSPHRASE) fields.push(`passphrase=${encodePayFastValue(PAYFAST_PASSPHRASE)}`);
  return crypto.createHash('md5').update(fields.join('&')).digest('hex');
};

const isAllowedSource = (sourceIp) => {
  const allowedIps = (process.env.PAYFAST_ALLOWED_IPS || '').split(',').map((ip) => ip.trim()).filter(Boolean);
  const normalizedIp = (sourceIp || '').replace(/^::ffff:/, '').split('%')[0];
  return allowedIps.includes(normalizedIp);
};

export const verifyItn = async (notification, sourceIp) => {
  if (!PAYFAST_MERCHANT_ID || !notification || typeof notification !== 'object') return false;
  if (!isAllowedSource(sourceIp)) {
    logger.warn('Rejected PayFast ITN from unconfigured source address');
    return false;
  }

  const providedSignature = notification.signature;
  const expectedSignature = generateSignature(notification);
  if (typeof providedSignature !== 'string'
      || providedSignature.length !== expectedSignature.length
      || !crypto.timingSafeEqual(Buffer.from(providedSignature), Buffer.from(expectedSignature))) {
    logger.warn('Rejected PayFast ITN with invalid signature');
    return false;
  }
  if (notification.merchant_id !== PAYFAST_MERCHANT_ID) return false;

  try {
    const form = new URLSearchParams();
    for (const [key, value] of Object.entries(notification)) {
      if (value !== undefined && value !== null) form.append(key, String(value));
    }
    const response = await axios.post(VALIDATION_URL, form.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      timeout: 10000
    });
    return response.data?.toString().trim() === 'VALID';
  } catch (error) {
    logger.error('PayFast ITN server validation failed:', error?.response?.data || error.message);
    throw new ExternalServiceError('Unable to validate PayFast notification', 'payfast');
  }
};

/**
 * Create payment
 */
export const createPayment = async (paymentData) => {
  try {
    assertPayFastConfig();

    logger.info('Creating PayFast payment', { amount: paymentData.amount });

    if (!paymentData.return_url || !paymentData.cancel_url || !paymentData.notify_url
        || !paymentData.email || !paymentData.item_name || !paymentData.reference) {
      throw new ExternalServiceError('Required PayFast checkout details are missing', 'payfast');
    }

    const payload = {
      merchant_id: PAYFAST_MERCHANT_ID,
      return_url: paymentData.return_url,
      cancel_url: paymentData.cancel_url,
      notify_url: paymentData.notify_url,
      name_first: paymentData.first_name,
      name_last: paymentData.last_name,
      email_address: paymentData.email,
      item_name: paymentData.item_name,
      item_description: paymentData.item_description,
      amount: Number(paymentData.amount).toFixed(2),
      custom_str1: paymentData.reference
    };

    payload.signature = generateSignature(payload);

    return {
      url: `${API_URL}/eng/process`,
      payload
    };
  } catch (error) {
    logger.error('PayFast payment creation error:', error?.message || error);
    throw new ExternalServiceError('Failed to create payment', 'payfast');
  }
};

/**
 * Verify payment
 */
export const verifyPayment = async (paymentId) => {
  try {
    assertPayFastConfig();
    logger.info('Verifying PayFast payment', { paymentId });

    const response = await axios.post(
      `${API_URL}/api/transaction`,
      {},
      {
        params: {
          merchant_id: PAYFAST_MERCHANT_ID,
          merchant_key: PAYFAST_MERCHANT_KEY,
          return_url: paymentId
        },
        headers: {
          Authorization: `Bearer ${PAYFAST_API_KEY || ''}`
        },
        timeout: 10000
      }
    );

    return response.data;
  } catch (error) {
    logger.error('PayFast verification error:', error?.response?.data || error.message);
    throw new ExternalServiceError('Failed to verify payment', 'payfast');
  }
};

/**
 * Process refund
 */
export const processRefund = async (transactionId, amount) => {
  try {
    assertPayFastConfig();
    logger.info('Processing PayFast refund', { transactionId, amount });

    const response = await axios.post(
      `${API_URL}/api/transaction/full_refund`,
      { amount },
      {
        params: {
          merchant_id: PAYFAST_MERCHANT_ID,
          merchant_key: PAYFAST_MERCHANT_KEY,
          transaction_id: transactionId
        },
        headers: {
          Authorization: `Bearer ${PAYFAST_API_KEY || ''}`
        },
        timeout: 10000
      }
    );

    return response.data;
  } catch (error) {
    logger.error('PayFast refund error:', error?.response?.data || error.message);
    throw new ExternalServiceError('Failed to process refund', 'payfast');
  }
};

export default {
  createPayment,
  verifyItn,
  verifyPayment,
  processRefund
};
