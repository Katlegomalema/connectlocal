/**
 * Payment Service
 * Booking payments and PayFast notification handling
 */

import * as paymentRepository from '../repositories/paymentRepository.js';
import * as payfast from '../integrations/payfast.js';
import { AuthorizationError, ConflictError, ExternalServiceError, NotFoundError, ValidationError } from '../utils/errors.js';

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

const getCheckoutUrls = () => {
  const publicApiUrl = process.env.PUBLIC_API_URL || process.env.API_BASE_URL;
  const frontendUrl = process.env.FRONTEND_URL;
  if (!publicApiUrl || !frontendUrl) {
    throw new ExternalServiceError('PUBLIC_API_URL/API_BASE_URL and FRONTEND_URL are required for PayFast checkout', 'payfast');
  }
  return {
    returnUrl: process.env.PAYFAST_RETURN_URL || `${frontendUrl.replace(/\/$/, '')}/payments/return`,
    cancelUrl: process.env.PAYFAST_CANCEL_URL || `${frontendUrl.replace(/\/$/, '')}/payments/cancel`,
    notifyUrl: process.env.PAYFAST_NOTIFY_URL || `${publicApiUrl.replace(/\/$/, '')}/api/v1/payments/payfast/itn`
  };
};

export const createPaymentIntent = async (actor, bookingId) => {
  if (actor?.role !== 'customer') throw new AuthorizationError('Only customers can pay for bookings');
  if (!bookingId) throw new ValidationError('bookingId is required');

  const booking = await paymentRepository.getBookingById(bookingId);
  if (booking.customer_id !== actor.id) throw new AuthorizationError('You do not own this booking');
  if (booking.status !== 'accepted') throw new ConflictError('Only accepted bookings can be paid');
  const amount = toAmount(booking.total_amount);
  if (!Number.isFinite(amount) || amount <= 0) throw new ValidationError('Booking has an invalid payment amount');

  let payment = await paymentRepository.getPaymentByBookingId(bookingId);
  if (payment && FINAL_STATUSES.includes(payment.payment_status)) {
    throw new ConflictError('This booking already has a completed payment');
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
      payment_status: 'pending'
    });
  }

  try {
    const customer = await paymentRepository.getUserById(actor.id);
    const nameParts = (customer.full_name || '').trim().split(/\s+/);
    const urls = getCheckoutUrls();
    const checkout = await payfast.createPayment({
      amount,
      return_url: urls.returnUrl,
      cancel_url: urls.cancelUrl,
      notify_url: urls.notifyUrl,
      first_name: nameParts[0] || 'Customer',
      last_name: nameParts.slice(1).join(' ') || 'ConnectLocal',
      email: customer.email,
      item_name: 'ConnectLocal service booking',
      item_description: `Booking ${booking.id}`,
      reference: payment.id,
      booking_id: booking.id
    });

    return {
      paymentId: payment.id,
      amount,
      currency: 'ZAR',
      status: payment.payment_status,
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
  return paymentRepository.listPayments({ bookingIds, status, page, limit });
};

export const getReceipt = async (actor, paymentId) => {
  const payment = await getPayment(actor, paymentId);
  if (!['paid', 'refunded', 'partially_refunded'].includes(payment.payment_status)) {
    throw new ConflictError('Receipt is not available until payment is confirmed');
  }
  const receipt = await paymentRepository.getReceiptByPaymentId(payment.id);
  if (!receipt) throw new NotFoundError('Receipt not found');
  const commission = 0;
  return {
    receiptNumber: `CL-${receipt.sequence_number}`,
    receiptUrl: receipt.receipt_url,
    paymentId: payment.id,
    bookingId: payment.booking_id,
    amount: toAmount(payment.amount),
    commission,
    netToProvider: toAmount(payment.amount) - commission,
    issuedAt: receipt.created_at,
    currency: 'ZAR',
    status: payment.payment_status
  };
};

export const confirmPayment = async (actor, paymentId) => getPayment(actor, paymentId);

export const processPayFastItn = async (notification, sourceIp) => {
  const valid = await payfast.verifyItn(notification, sourceIp);
  if (!valid) return { accepted: false, processed: false };

  const paymentId = notification.custom_str1;
  if (!paymentId) return { accepted: true, processed: false };
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
    return { accepted: true, processed: true, payment: updated };
  }

  if (['FAILED', 'CANCELLED'].includes(notification.payment_status)) {
    const updated = await paymentRepository.updatePayment(payment.id, ['pending'], {
      payment_status: 'failed',
      gateway_response_raw: notification
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
  return paymentRepository.updatePayment(payment.id, ['paid'], {
    payment_status: 'refunded',
    refunded_amount: payment.amount
  });
};

export default {
  createPaymentIntent,
  confirmPayment,
  getPayment,
  listPayments,
  getReceipt,
  processPayFastItn,
  processRefund
};
