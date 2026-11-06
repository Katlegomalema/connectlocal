/**
 * PayFast (South Africa). SANDBOX unless PAYFAST_MODE=live.
 *
 * Checkout:  the backend builds and signs the form; the app opens our auto-submitting checkout page
 *            (GET /api/v1/payments/:id/checkout), which posts it to PayFast. Merchant key and passphrase
 *            never reach the Flutter app.
 * ITN:       PayFast POSTs to notify_url. A notification is only trusted when ALL of these pass
 *            (PayFast's own checklist): signature, source IP is PayFast, amount matches our record
 *            (checked in paymentService), and PayFast confirms it via /eng/query/validate.
 * Refunds:   PayFast API v1 (api.payfast.co.za/refunds), signed request headers; `?testing=true` in sandbox.
 */

import axios from 'axios';
import crypto from 'node:crypto';
import dns from 'node:dns/promises';
import logger from '../utils/logger.js';
import { ExternalServiceError } from '../utils/errors.js';

const config = () => ({
  merchantId: process.env.PAYFAST_MERCHANT_ID,
  merchantKey: process.env.PAYFAST_MERCHANT_KEY,
  passphrase: process.env.PAYFAST_PASSPHRASE || '',
  sandbox: (process.env.PAYFAST_MODE || 'sandbox').toLowerCase() !== 'live'
});

export const isSandbox = () => config().sandbox;
const siteUrl = () => (config().sandbox ? 'https://sandbox.payfast.co.za' : 'https://www.payfast.co.za');
const API_HOST = 'https://api.payfast.co.za';

/** Hosts PayFast sends ITNs from (their docs). */
const PAYFAST_HOSTS = ['www.payfast.co.za', 'sandbox.payfast.co.za', 'w1w.payfast.co.za', 'w2w.payfast.co.za'];

const assertConfigured = () => {
  const { merchantId, merchantKey } = config();
  if (!merchantId || !merchantKey || !/^\d+$/.test(merchantId)) {
    throw new ExternalServiceError(
      'PayFast is not configured: set PAYFAST_MERCHANT_ID (numbers only), PAYFAST_MERCHANT_KEY and PAYFAST_PASSPHRASE',
      'payfast'
    );
  }
};

// ---- signing ---------------------------------------------------------------------------------------------
/** PHP urlencode(): like encodeURIComponent, but also encodes !'()*~ and uses + for spaces (uppercase hex). */
export const phpUrlEncode = (value) => encodeURIComponent(String(value))
  .replace(/[!'()*~]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`)
  .replace(/%20/g, '+');

const md5 = (text) => crypto.createHash('md5').update(text).digest('hex');

/** Checkout form fields, in the order PayFast documents (the signature depends on this order). */
export const CHECKOUT_FIELD_ORDER = [
  'merchant_id', 'merchant_key', 'return_url', 'cancel_url', 'notify_url',
  'name_first', 'name_last', 'email_address', 'cell_number',
  'm_payment_id', 'amount', 'item_name', 'item_description',
  'custom_int1', 'custom_int2', 'custom_int3', 'custom_int4', 'custom_int5',
  'custom_str1', 'custom_str2', 'custom_str3', 'custom_str4', 'custom_str5',
  'email_confirmation', 'confirmation_address', 'payment_method'
];

/** Signature for the checkout form: non-blank fields, documented order, then the passphrase. */
export const checkoutSignature = (fields, passphrase = config().passphrase) => {
  const parts = CHECKOUT_FIELD_ORDER
    .filter((key) => fields[key] !== undefined && fields[key] !== null && String(fields[key]).trim() !== '')
    .map((key) => `${key}=${phpUrlEncode(String(fields[key]).trim())}`);
  if (passphrase) parts.push(`passphrase=${phpUrlEncode(passphrase.trim())}`);
  return md5(parts.join('&'));
};

/**
 * Signature of an ITN: every posted field except `signature`, IN THE ORDER RECEIVED (blank ones too), then
 * the passphrase. Same as PayFast's PHP sample.
 */
export const itnSignature = (posted, passphrase = config().passphrase) => {
  const parts = Object.entries(posted)
    .filter(([key]) => key !== 'signature')
    .map(([key, value]) => `${key}=${phpUrlEncode(String(value ?? '').trim())}`);
  if (passphrase) parts.push(`passphrase=${phpUrlEncode(passphrase.trim())}`);
  return md5(parts.join('&'));
};

const sameHex = (a, b) => typeof a === 'string' && typeof b === 'string' && a.length === b.length
  && crypto.timingSafeEqual(Buffer.from(a.toLowerCase()), Buffer.from(b.toLowerCase()));

// ---- source IP -------------------------------------------------------------------------------------------
let ipCache = { ips: new Set(), at: 0 };

const payfastIps = async () => {
  if (Date.now() - ipCache.at < 10 * 60 * 1000 && ipCache.ips.size) return ipCache.ips;
  const ips = new Set((process.env.PAYFAST_ALLOWED_IPS || '').split(',').map((ip) => ip.trim()).filter(Boolean));
  await Promise.all(PAYFAST_HOSTS.map(async (host) => {
    try {
      (await dns.resolve4(host)).forEach((ip) => ips.add(ip));
    } catch {
      // a host that does not resolve is simply skipped
    }
  }));
  ipCache = { ips, at: Date.now() };
  return ips;
};

const normaliseIp = (ip) => String(ip || '').trim().replace(/^::ffff:/, '').split('%')[0];

/**
 * True when the request came from PayFast. Behind a proxy (Codespaces, Render...) the real sender is in
 * X-Forwarded-For; any hop matching a PayFast address counts. This is defence in depth only: a forged ITN
 * still fails the signature and PayFast's own validation.
 */
export const isFromPayFast = async (sourceAddresses) => {
  const allowed = await payfastIps();
  return sourceAddresses.map(normaliseIp).some((ip) => allowed.has(ip));
};

// ---- checkout --------------------------------------------------------------------------------------------
/**
 * Signed checkout form. Returns { url, fields } to POST (our checkout page does that in the browser).
 */
export const createPayment = async (paymentData) => {
  assertConfigured();
  const { merchantId, merchantKey } = config();
  if (!paymentData.return_url || !paymentData.cancel_url || !paymentData.notify_url
      || !paymentData.email || !paymentData.item_name || !paymentData.reference) {
    throw new ExternalServiceError('Required PayFast checkout details are missing', 'payfast');
  }

  const fields = {
    merchant_id: merchantId,
    merchant_key: merchantKey,
    return_url: paymentData.return_url,
    cancel_url: paymentData.cancel_url,
    notify_url: paymentData.notify_url,
    name_first: paymentData.first_name,
    name_last: paymentData.last_name,
    email_address: paymentData.email,
    m_payment_id: paymentData.reference, // our payment id; comes back in the ITN
    amount: Number(paymentData.amount).toFixed(2),
    item_name: String(paymentData.item_name).slice(0, 100),
    item_description: paymentData.item_description ? String(paymentData.item_description).slice(0, 255) : undefined,
    custom_str1: paymentData.reference,
    custom_str2: paymentData.booking_id
  };
  const ordered = Object.fromEntries(CHECKOUT_FIELD_ORDER
    .filter((key) => fields[key] !== undefined && fields[key] !== null && String(fields[key]).trim() !== '')
    .map((key) => [key, String(fields[key]).trim()]));
  ordered.signature = checkoutSignature(ordered);

  return { url: `${siteUrl()}/eng/process`, payload: ordered };
};

// ---- ITN -------------------------------------------------------------------------------------------------
/**
 * Checks signature, merchant, source IP and PayFast's server validation. The amount is checked by the caller
 * against our own payment record. Returns true only when everything passes.
 */
export const verifyItn = async (notification, sourceAddresses = []) => {
  if (!notification || typeof notification !== 'object') return false;
  const { merchantId } = config();
  if (!merchantId || notification.merchant_id !== merchantId) {
    logger.warn('Rejected PayFast ITN for another merchant');
    return false;
  }
  if (!sameHex(notification.signature, itnSignature(notification))) {
    logger.warn('Rejected PayFast ITN with invalid signature');
    return false;
  }
  const addresses = Array.isArray(sourceAddresses) ? sourceAddresses : [sourceAddresses];
  if (!(await isFromPayFast(addresses))) {
    logger.warn({ addresses }, 'Rejected PayFast ITN from a non-PayFast address');
    return false;
  }

  // Ask PayFast to confirm the exact data it sent.
  const body = Object.entries(notification)
    .filter(([key]) => key !== 'signature')
    .map(([key, value]) => `${key}=${phpUrlEncode(String(value ?? '').trim())}`)
    .join('&');
  try {
    const response = await axios.post(`${siteUrl()}/eng/query/validate`, body, {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      timeout: 10000
    });
    const valid = String(response.data).trim() === 'VALID';
    if (!valid) logger.warn('PayFast did not confirm the ITN (INVALID)');
    return valid;
  } catch (error) {
    logger.error({ err: error.message }, 'PayFast ITN server validation failed');
    throw new ExternalServiceError('Unable to validate PayFast notification', 'payfast');
  }
};

// ---- refunds (API v1) ------------------------------------------------------------------------------------
/** PayFast API signature: all headers + body fields + passphrase, sorted alphabetically, urlencoded, md5. */
export const apiSignature = (values, passphrase = config().passphrase) => {
  const all = { ...values, ...(passphrase ? { passphrase } : {}) };
  return md5(Object.keys(all).sort()
    .map((key) => `${key}=${phpUrlEncode(String(all[key]).trim())}`)
    .join('&'));
};

/** Full or partial refund of a PayFast payment (amount in rand). */
export const processRefund = async (pfPaymentId, amount, reason = 'ConnectLocal booking fee refund') => {
  assertConfigured();
  const { merchantId } = config();
  const headers = {
    'merchant-id': merchantId,
    version: 'v1',
    timestamp: new Date().toISOString().replace(/\.\d{3}Z$/, '+00:00')
  };
  const body = { amount: Math.round(Number(amount) * 100), reason };
  const url = `${API_HOST}/refunds/${encodeURIComponent(pfPaymentId)}${config().sandbox ? '?testing=true' : ''}`;
  try {
    const response = await axios.post(url, body, {
      headers: { ...headers, signature: apiSignature({ ...headers, ...body }), 'Content-Type': 'application/json' },
      timeout: 15000
    });
    return response.data;
  } catch (error) {
    logger.error({ status: error?.response?.status, data: error?.response?.data }, 'PayFast refund failed');
    throw new ExternalServiceError('PayFast could not process the refund', 'payfast');
  }
};

export default {
  isSandbox,
  phpUrlEncode,
  checkoutSignature,
  itnSignature,
  apiSignature,
  isFromPayFast,
  createPayment,
  verifyItn,
  processRefund
};
