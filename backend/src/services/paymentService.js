/**
 * Payment Service
 * Booking payments and PayFast notification handling
 */

import * as paymentRepository from '../repositories/paymentRepository.js';
import * as payfast from '../integrations/payfast.js';
import * as payoutService from './payoutService.js';
import { notifyBookingEvent } from './bookingNotifier.js';
import logger from '../utils/logger.js';
import { COMMISSION_RATE, commissionFor } from '../config/business.js';
import { checkoutToken, checkoutTokenValid } from '../utils/secureCodes.js';
import {
  AuthenticationError, AuthorizationError, ConflictError, ExternalServiceError, NotFoundError, ValidationError
} from '../utils/errors.js';

const FINAL_STATUSES = ['paid', 'refunded', 'partially_refunded'];

const assertPaymentParty = async (actor, booking) => {
  if (actor.role === 'admin' || booking.customer_id === actor.id) return;
  if (actor.role === 'provider') {
    const provider = await paymentRepository.getProviderByUserId(actor.id);
    if (provider.id === booking.provider_id) return;
  }
  throw new AuthorizationError('You are not a party to this payment');
};

const toAmount = (value) => Math.round(Number(value) * 100) / 100;

/** Public HTTPS address of this API (PayFast must reach notify_url). */
const publicApiUrl = () => {
  const url = (process.env.PUBLIC_API_URL || process.env.API_BASE_URL || '').replace(/\/$/, '');
  if (!url) throw new ExternalServiceError('PUBLIC_API_URL is required for PayFast checkout', 'payfast');
  return url;
};

const getCheckoutUrls = (paymentId) => {
  const api = publicApiUrl();
  return {
    // Simple pages on this API ("you can go back to the app"); the app polls the payment status itself.
    returnUrl: process.env.PAYFAST_RETURN_URL || `${api}/api/v1/payments/return?payment=${paymentId}`,
    cancelUrl: process.env.PAYFAST_CANCEL_URL || `${api}/api/v1/payments/cancel?payment=${paymentId}`,
    notifyUrl: process.env.PAYFAST_NOTIFY_URL || `${api}/api/v1/payments/payfast/itn`
  };
};

const CHECKOUT_LINK_SECONDS = 30 * 60;

/** Link the app opens: our page that posts the signed form to PayFast. */
const checkoutLink = (paymentId) => {
  const expires = Math.floor(Date.now() / 1000) + CHECKOUT_LINK_SECONDS;
  return `${publicApiUrl()}/api/v1/payments/${paymentId}/checkout?e=${expires}&t=${checkoutToken(paymentId, expires)}`;
};

/** Signed PayFast form for a pending payment. */
const buildCheckout = async (payment, booking, purposeConfigValue) => {
  const customer = await paymentRepository.getUserById(booking.customer_id);
  const nameParts = (customer.full_name || '').trim().split(/\s+/);
  const urls = getCheckoutUrls(payment.id);
  return payfast.createPayment({
    amount: toAmount(payment.amount),
    return_url: urls.returnUrl,
    cancel_url: urls.cancelUrl,
    notify_url: urls.notifyUrl,
    first_name: nameParts[0] || 'Customer',
    last_name: nameParts.slice(1).join(' ') || 'ConnectLocal',
    email: customer.email,
    item_name: purposeConfigValue.itemName,
    item_description: `Booking ${booking.id}`,
    reference: payment.id,
    booking_id: booking.id
  });
};

const PURPOSES = {
  booking_fee: {
    bookingStatus: 'pending',
    stateColumn: 'booking_fee_status',
    amountColumn: 'booking_fee_amount',
    itemName: 'ConnectLocal booking fee (15% deposit)',
    wrongStatus: 'The booking fee can only be paid while the booking is pending'
  },
  balance: {
    bookingStatus: 'completed',
    stateColumn: 'balance_status',
    amountColumn: 'balance_amount',
    itemName: 'ConnectLocal service balance',
    wrongStatus: 'The balance can only be paid after the job is completed'
  }
};

const purposeConfig = (purpose) => {
  const config = PURPOSES[purpose];
  if (!config) throw new ValidationError('purpose must be booking_fee or balance');
  return config;
};

/**
 * Card checkout (PayFast) for the 15% booking fee or for the balance after completion.
 */
export const createPaymentIntent = async (actor, bookingId, purpose = 'booking_fee') => {
  if (actor?.role !== 'customer') throw new AuthorizationError('Only customers can pay for bookings');
  if (!bookingId) throw new ValidationError('bookingId is required');
  const config = purposeConfig(purpose);

  const booking = await paymentRepository.getBookingById(bookingId);
  if (booking.customer_id !== actor.id) throw new AuthorizationError('You do not own this booking');
  if (booking.status !== config.bookingStatus) throw new ConflictError(config.wrongStatus);
  if (booking[config.stateColumn] === 'paid') throw new ConflictError('This part of the booking is already paid');
  if (!['pending', 'failed'].includes(booking[config.stateColumn])) {
    throw new ConflictError('This part of the booking can no longer be paid');
  }
  const amount = toAmount(booking[config.amountColumn]);
  if (!Number.isFinite(amount) || amount <= 0) throw new ValidationError('Booking has an invalid payment amount');

  let payment = await paymentRepository.getPaymentByBookingAndPurpose(bookingId, purpose);
  if (payment && FINAL_STATUSES.includes(payment.payment_status)) {
    throw new ConflictError('This part of the booking is already paid');
  }
  if (payment?.payment_status === 'failed') {
    payment = await paymentRepository.updatePayment(payment.id, ['failed'], {
      payment_status: 'pending',
      amount,
      transaction_reference: null,
      gateway_response_raw: null
    });
  }
  if (!payment) {
    payment = await paymentRepository.createPayment({
      booking_id: bookingId,
      amount,
      currency: 'ZAR',
      gateway_provider: 'payfast',
      payment_status: 'pending',
      purpose,
      method: 'card'
    });
  }

  try {
    const checkout = await buildCheckout(payment, booking, config);
    return {
      paymentId: payment.id,
      purpose,
      amount,
      currency: 'ZAR',
      status: payment.payment_status,
      sandbox: payfast.isSandbox(),
      // Open this in a browser; it posts the signed form to PayFast. Then poll GET /payments/:paymentId.
      checkoutUrl: checkoutLink(payment.id),
      redirectUrl: checkout.url,
      fields: checkout.payload
    };
  } catch (error) {
    if (payment.payment_status === 'pending') {
      await paymentRepository.updatePayment(payment.id, ['pending'], { payment_status: 'failed' });
    }
    throw error;
  }
};

/**
 * Payout for a finished job: price - 10% commission - cash the provider already collected.
 * Created automatically when the balance is paid (admin never marks payouts).
 */
const createPayoutForBooking = async (booking, cashCollected = 0) => {
  const gross = toAmount(booking.total_amount);
  const payout = await paymentRepository.createPayout({
    booking_id: booking.id,
    provider_id: booking.provider_id,
    gross_amount: gross,
    commission_rate: COMMISSION_RATE,
    commission_amount: commissionFor(gross),
    cash_collected_amount: toAmount(cashCollected),
    status: 'pending'
  });
  // Automatic: paid out straight away (now that the row exists), and by the timer as a fallback.
  setImmediate(() => payoutService.processPendingPayouts().catch((error) => logger.error({ err: error }, 'Payout run failed')));
  return payout;
};

/** Apply a confirmed card payment to its booking. */
const applyPaidPayment = async (payment) => {
  const booking = await paymentRepository.getBookingById(payment.booking_id);
  if (payment.purpose === 'balance') {
    await paymentRepository.updateBookingPaymentState(booking.id, {}, {
      balance_status: 'paid',
      balance_payment_method: 'card'
    });
    await createPayoutForBooking(booking, 0);
    await notifyBookingEvent('balancePaid', booking.id, { method: 'card' });
  } else {
    await paymentRepository.updateBookingPaymentState(booking.id, {}, { booking_fee_status: 'paid' });
    if (booking.status !== 'pending') {
      // Paid from an old checkout tab after the booking was cancelled/declined: give the money back.
      try {
        // eslint-disable-next-line no-use-before-define -- defined below; only called later, at run time
        await refundBookingFee({ ...booking, booking_fee_status: 'paid' });
      } catch (error) {
        logger.error({ err: error, bookingId: booking.id }, 'Late booking fee could not be refunded; needs admin follow-up');
      }
      return;
    }
    // Only now can the provider accept, so this is when they hear about the request.
    await notifyBookingEvent('requested', booking.id);
  }
};

/**
 * The provider confirms the customer paid the balance in cash.
 */
export const recordCashBalance = async (actor, bookingId) => {
  if (actor?.role !== 'provider') throw new AuthorizationError('Only the provider can confirm a cash payment');
  const booking = await paymentRepository.getBookingById(bookingId);
  const provider = await paymentRepository.getProviderByUserId(actor.id);
  if (provider.id !== booking.provider_id) throw new AuthorizationError('You do not own this booking');
  if (booking.status !== 'completed') throw new ConflictError(PURPOSES.balance.wrongStatus);
  if (booking.balance_status === 'paid') throw new ConflictError('The balance is already paid');

  const amount = toAmount(booking.balance_amount);
  const payment = await paymentRepository.createPayment({
    booking_id: booking.id,
    amount,
    currency: 'ZAR',
    gateway_provider: null,
    payment_status: 'paid',
    purpose: 'balance',
    method: 'cash',
    paid_at: new Date().toISOString()
  });
  await paymentRepository.updateBookingPaymentState(booking.id, { balance_status: booking.balance_status }, {
    balance_status: 'paid',
    balance_payment_method: 'cash'
  });
  await paymentRepository.createReceipt(payment.id);
  const payout = await createPayoutForBooking(booking, amount);
  await notifyBookingEvent('balancePaid', booking.id, { method: 'cash' });
  return { payment, payout };
};

/**
 * Refund the booking fee (provider declined, or customer cancelled while pending).
 * Returns true when money was sent back.
 */
export const refundBookingFee = async (booking) => {
  if (booking.booking_fee_status !== 'paid') return false;
  const payment = await paymentRepository.getPaymentByBookingAndPurpose(booking.id, 'booking_fee');
  if (!payment || payment.payment_status !== 'paid') return false;
  if (!payment.transaction_reference) throw new ConflictError('PayFast transaction reference is missing');

  await payfast.processRefund(payment.transaction_reference, payment.amount);
  await paymentRepository.updatePayment(payment.id, ['paid'], {
    payment_status: 'refunded',
    refunded_amount: payment.amount
  });
  await paymentRepository.updateBookingPaymentState(booking.id, { booking_fee_status: 'paid' }, {
    booking_fee_status: 'refunded'
  });
  return true;
};

export const getPayment = async (actor, paymentId) => {
  const payment = await paymentRepository.getPaymentById(paymentId);
  const booking = await paymentRepository.getBookingById(payment.booking_id);
  await assertPaymentParty(actor, booking);
  return payment;
};

export const listPayments = async (actor, { page: pageValue, limit: limitValue, status } = {}) => {
  const page = Number.parseInt(pageValue, 10) || 1;
  const limit = Number.parseInt(limitValue, 10) || 20;
  if (!Number.isInteger(page) || !Number.isInteger(limit) || page < 1 || limit < 1 || limit > 100) {
    throw new ValidationError('page must be positive and limit must be between 1 and 100');
  }
  if (status && !['pending', 'paid', 'failed', 'refunded'].includes(status)) {
    throw new ValidationError('Invalid payment status');
  }

  let bookingIds;
  if (actor.role === 'customer') {
    bookingIds = await paymentRepository.listBookingIdsForCustomer(actor.id);
  } else if (actor.role === 'provider') {
    const provider = await paymentRepository.getProviderByUserId(actor.id);
    bookingIds = await paymentRepository.listBookingIdsForProvider(provider.id);
  } else {
    throw new AuthorizationError('Payment history is limited to booking participants');
  }
  return paymentRepository.listPayments({
    bookingIds, status, page, limit
  });
};

export const getReceipt = async (actor, paymentId) => {
  const payment = await getPayment(actor, paymentId);
  if (!['paid', 'refunded', 'partially_refunded'].includes(payment.payment_status)) {
    throw new ConflictError('Receipt is not available until payment is confirmed');
  }
  const receipt = await paymentRepository.getReceiptByPaymentId(payment.id);
  if (!receipt) throw new NotFoundError('Receipt not found');
  // Commission is taken from the job price once, on the payout (fee receipts show none).
  const payout = payment.purpose === 'balance'
    ? await paymentRepository.getPayoutByBookingId(payment.booking_id)
    : null;
  const commission = payout ? toAmount(payout.commission_amount) : 0;
  return {
    purpose: payment.purpose,
    method: payment.method,
    receiptNumber: `CL-${receipt.sequence_number}`,
    receiptUrl: receipt.receipt_url,
    paymentId: payment.id,
    bookingId: payment.booking_id,
    amount: toAmount(payment.amount),
    commission,
    netToProvider: payout ? toAmount(payout.payout_amount) : null,
    issuedAt: receipt.created_at,
    currency: 'ZAR',
    status: payment.payment_status
  };
};

export const confirmPayment = async (actor, paymentId) => getPayment(actor, paymentId);

/**
 * For GET /payments/:id/checkout (opened in a browser, no app login): the signed PayFast form, if the link
 * token is valid and the payment is still waiting.
 */
export const getCheckoutForm = async (paymentId, expires, token) => {
  if (!checkoutTokenValid(paymentId, expires, token)) {
    throw new AuthenticationError('This payment link has expired. Go back to the app and tap Pay again.');
  }
  const payment = await paymentRepository.getPaymentById(paymentId);
  if (payment.payment_status !== 'pending') throw new ConflictError('This payment is already finished');
  const booking = await paymentRepository.getBookingById(payment.booking_id);
  const config = purposeConfig(payment.purpose || 'booking_fee');
  // The link lives 30 minutes: the booking may have been cancelled or declined since.
  if (booking.status !== config.bookingStatus) throw new ConflictError(config.wrongStatus);
  return buildCheckout(payment, booking, config);
};

export const processPayFastItn = async (notification, sourceIp) => {
  const valid = await payfast.verifyItn(notification, sourceIp);
  if (!valid) return { accepted: false, processed: false };

  const paymentId = notification.m_payment_id || notification.custom_str1;
  if (typeof paymentId !== 'string' || !/^[0-9a-f-]{36}$/i.test(paymentId)) return { accepted: true, processed: false };
  const payment = await paymentRepository.getPaymentById(paymentId);
  if (FINAL_STATUSES.includes(payment.payment_status)) return { accepted: true, processed: false };
  if (payment.payment_status !== 'pending') return { accepted: true, processed: false };

  const callbackAmount = toAmount(notification.amount_gross);
  if (!Number.isFinite(callbackAmount) || callbackAmount !== toAmount(payment.amount)) {
    throw new ConflictError('PayFast amount does not match the payment record');
  }

  if (notification.payment_status === 'COMPLETE') {
    const updated = await paymentRepository.updatePayment(payment.id, ['pending'], {
      payment_status: 'paid',
      transaction_reference: notification.pf_payment_id || null,
      gateway_response_raw: notification,
      paid_at: new Date().toISOString()
    });
    await paymentRepository.createReceipt(payment.id);
    await applyPaidPayment(updated);
    return { accepted: true, processed: true, payment: updated };
  }

  if (['FAILED', 'CANCELLED'].includes(notification.payment_status)) {
    const updated = await paymentRepository.updatePayment(payment.id, ['pending'], {
      payment_status: 'failed',
      gateway_response_raw: notification
    });
    const { stateColumn } = purposeConfig(updated.purpose || 'booking_fee');
    await paymentRepository.updateBookingPaymentState(updated.booking_id, { [stateColumn]: 'pending' }, {
      [stateColumn]: 'failed'
    }).catch((error) => {
      // Booking already moved on (e.g. a retry was paid): nothing to do. Anything else is a real error.
      if (!(error instanceof ConflictError)) throw error;
    });
    return { accepted: true, processed: true, payment: updated };
  }

  return { accepted: true, processed: false };
};

export const processRefund = async (actor, paymentId) => {
  if (actor?.role !== 'admin') throw new AuthorizationError('Only an administrator can issue refunds');
  const payment = await paymentRepository.getPaymentById(paymentId);
  if (payment.payment_status !== 'paid') throw new ConflictError('Only paid transactions can be refunded');
  if (!payment.transaction_reference) throw new ConflictError('PayFast transaction reference is missing');

  await payfast.processRefund(payment.transaction_reference, payment.amount);
  const refunded = await paymentRepository.updatePayment(payment.id, ['paid'], {
    payment_status: 'refunded',
    refunded_amount: payment.amount
  });
  const { stateColumn } = purposeConfig(payment.purpose || 'booking_fee');
  await paymentRepository.updateBookingPaymentState(payment.booking_id, {}, { [stateColumn]: 'refunded' });
  return refunded;
};

export default {
  createPaymentIntent,
  getCheckoutForm,
  recordCashBalance,
  refundBookingFee,
  confirmPayment,
  getPayment,
  listPayments,
  getReceipt,
  processPayFastItn,
  processRefund
};
