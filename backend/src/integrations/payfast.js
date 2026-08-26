/**
 * PayFast Payment Gateway Integration
 * South African payment processing
 */

import axios from 'axios';
import crypto from 'crypto';
import logger from '../utils/logger.js';
import { ExternalServiceError, ValidationError } from '../utils/errors.js';

const PAYFAST_MERCHANT_ID = process.env.PAYFAST_MERCHANT_ID;
const PAYFAST_MERCHANT_KEY = process.env.PAYFAST_MERCHANT_KEY;
const PAYFAST_API_KEY = process.env.PAYFAST_API_KEY;
const PAYFAST_PASSPHRASE = process.env.PAYFAST_PASSPHRASE;

// PayFast endpoints
const SANDBOX_URL = 'https://sandbox.payfast.co.za';
const LIVE_URL = 'https://www.payfast.co.za';
const API_URL = process.env.NODE_ENV === 'production' ? LIVE_URL : SANDBOX_URL;

/**
 * Generate PayFast signature
 */
const generateSignature = (data) => {
  const signature = crypto
    .createHash('md5')
    .update(data)
    .digest('hex');
  return signature;
};

/**
 * Create payment
 */
export const createPayment = async (paymentData) => {
  try {
    logger.info('Creating PayFast payment', { amount: paymentData.amount });

    const payload = {
      merchant_id: PAYFAST_MERCHANT_ID,
      merchant_key: PAYFAST_MERCHANT_KEY,
      return_url: paymentData.return_url,
      cancel_url: paymentData.cancel_url,
      notify_url: paymentData.notify_url,
      name_first: paymentData.first_name,
      name_last: paymentData.last_name,
      email_address: paymentData.email,
      item_name: paymentData.item_name,
      item_description: paymentData.item_description,
      amount: paymentData.amount.toFixed(2),
      custom_int1: paymentData.booking_id,
      custom_str1: paymentData.reference
    };

    // Generate signature
    const signatureString = Object.keys(payload)
      .sort()
      .map(key => `${key}=${encodeURIComponent(payload[key])}`)
      .join('&');

    payload.signature = generateSignature(signatureString);

    return {
      url: `${API_URL}/eng/process`,
      payload
    };
  } catch (error) {
    logger.error('PayFast payment creation error:', error);
    throw new ExternalServiceError('Failed to create payment', 'payfast');
  }
};

/**
 * Verify payment
 */
export const verifyPayment = async (paymentId) => {
  try {
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
          'Authorization': `Bearer ${PAYFAST_API_KEY}`
        }
      }
    );

    return response.data;
  } catch (error) {
    logger.error('PayFast verification error:', error);
    throw new ExternalServiceError('Failed to verify payment', 'payfast');
  }
};

/**
 * Process refund
 */
export const processRefund = async (transactionId, amount) => {
  try {
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
          'Authorization': `Bearer ${PAYFAST_API_KEY}`
        }
      }
    );

    return response.data;
  } catch (error) {
    logger.error('PayFast refund error:', error);
    throw new ExternalServiceError('Failed to process refund', 'payfast');
  }
};

export default {
  createPayment,
  verifyPayment,
  processRefund
};
