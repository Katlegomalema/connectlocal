/**
 * Payment Repository
 * Database operations for booking payments
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { ConflictError, NotFoundError } from '../utils/errors.js';

export const getBookingById = async (bookingId) => {
  const { data, error } = await supabase
    .from('bookings')
    // Everything the payment flow reads: fee/balance amounts and their payment state.
    .select('id, customer_id, provider_id, status, total_amount, booking_fee_amount, booking_fee_status, '
      + 'balance_amount, balance_status, balance_payment_method')
    .eq('id', bookingId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Booking not found');
  return data;
};

export const getProviderByUserId = async (userId) => {
  const { data, error } = await supabase
    .from('providers')
    .select('id, user_id')
    .eq('user_id', userId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Provider profile not found');
  return data;
};

export const getUserById = async (userId) => {
  const { data, error } = await supabase
    .from('users')
    .select('id, email, full_name, is_active, deleted_at')
    .eq('id', userId)
    .maybeSingle();

  if (error) throw error;
  if (!data || !data.is_active || data.deleted_at) throw new NotFoundError('User not found');
  return data;
};

export const getPaymentById = async (paymentId) => {
  const { data, error } = await supabase
    .from('payments')
    .select('*')
    .eq('id', paymentId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Payment not found');
  return data;
};

/** Latest payment row for a booking and purpose ('booking_fee' or 'balance'). */
export const getPaymentByBookingAndPurpose = async (bookingId, purpose) => {
  const { data, error } = await supabase
    .from('payments')
    .select('*')
    .eq('booking_id', bookingId)
    .eq('purpose', purpose)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return data;
};

/** Record the fee / balance state on the booking. Guarded by the expected current value. */
export const updateBookingPaymentState = async (bookingId, expected, updates) => {
  let query = supabase.from('bookings').update(updates).eq('id', bookingId);
  for (const [column, value] of Object.entries(expected)) query = query.eq(column, value);
  const { data, error } = await query.select('id').maybeSingle();

  if (error) throw error;
  if (!data) throw new ConflictError('Booking payment state changed; reload and try again');
  return data;
};

export const getPayoutByBookingId = async (bookingId) => {
  const { data, error } = await supabase
    .from('payouts')
    .select('*')
    .eq('booking_id', bookingId)
    .maybeSingle();

  if (error) throw error;
  return data;
};

/** One payout per booking (unique). Returns the existing one if it was already created. */
export const createPayout = async (payout) => {
  const { data, error } = await supabase
    .from('payouts')
    .insert(payout)
    .select('*')
    .single();

  if (error?.code === '23505') return getPayoutByBookingId(payout.booking_id);
  if (error) throw error;
  return data;
};

/** Another request created the same payment at the same moment (unique index on key / open payment). */
export class DuplicatePaymentError extends ConflictError {
  constructor() {
    super('A payment for this is already being made');
    this.code = 'DUPLICATE_PAYMENT';
  }
}

export const createPayment = async (payment) => {
  const { data, error } = await supabase
    .from('payments')
    .insert(payment)
    .select('*')
    .single();

  if (error?.code === '23505') {
    const text = `${error.message} ${error.details || ''}`;
    if (/uq_payments_idempotency_key|uq_payments_one_open_per_purpose/.test(text)) throw new DuplicatePaymentError();
    throw new ConflictError('This part of the booking is already paid');
  }
  if (error) throw error;
  return data;
};

/** The payment started with this Idempotency-Key, or null. */
export const getPaymentByIdempotencyKey = async (key) => {
  const { data, error } = await supabase
    .from('payments')
    .select('*')
    .eq('idempotency_key', key)
    .maybeSingle();
  if (error) throw error;
  return data;
};

/** The open (pending) or paid payment for a booking and purpose, paid first, or null. */
export const getActivePayment = async (bookingId, purpose) => {
  const { data, error } = await supabase
    .from('payments')
    .select('*')
    .eq('booking_id', bookingId)
    .eq('purpose', purpose)
    .in('payment_status', ['paid', 'pending'])
    .order('payment_status', { ascending: false }) // 'pending' < 'paid' alphabetically: paid first
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data;
};

/**
 * A verified COMPLETE ITN: payment paid + receipt + booking fee/balance paid, in ONE database transaction
 * with the payment row locked (migration 20261106120000). Returns { outcome, ... }:
 * paid | already_processed | amount_mismatch | duplicate_reference | not_found.
 */
export const applyPayfastPayment = async (paymentId, pfPaymentId, amount, raw) => {
  const { data, error } = await supabase.rpc('apply_payfast_payment', {
    p_payment_id: paymentId,
    p_pf_payment_id: pfPaymentId,
    p_amount: amount,
    p_raw: raw
  });
  if (error) throw error;
  return data;
};

export const updatePayment = async (paymentId, allowedStatuses, updates) => {
  const { data, error } = await supabase
    .from('payments')
    .update(updates)
    .eq('id', paymentId)
    .in('payment_status', allowedStatuses)
    .select('*')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new ConflictError('Payment status changed; reload and try again');
  return data;
};

export const listBookingIdsForCustomer = async (userId) => {
  const { data, error } = await supabase
    .from('bookings')
    .select('id')
    .eq('customer_id', userId);

  if (error) throw error;
  return (data || []).map((booking) => booking.id);
};

export const listBookingIdsForProvider = async (providerId) => {
  const { data, error } = await supabase
    .from('bookings')
    .select('id')
    .eq('provider_id', providerId);

  if (error) throw error;
  return (data || []).map((booking) => booking.id);
};

export const listPayments = async ({
  bookingIds, status, page, limit
}) => {
  if (!bookingIds.length) {
    return {
      payments: [], total: 0, page, pages: 0
    };
  }
  let query = supabase
    .from('payments')
    .select('*', { count: 'exact' })
    .in('booking_id', bookingIds)
    .order('created_at', { ascending: false });
  if (status) query = query.eq('payment_status', status);

  const offset = (page - 1) * limit;
  const { data, error, count } = await query.range(offset, offset + limit - 1);
  if (error) throw error;
  return {
    payments: data || [],
    total: count || 0,
    page,
    pages: Math.ceil((count || 0) / limit)
  };
};

export const getReceiptByPaymentId = async (paymentId) => {
  const { data, error } = await supabase
    .from('receipts')
    .select('*')
    .eq('payment_id', paymentId)
    .maybeSingle();
  if (error) throw error;
  return data;
};

export const createReceipt = async (paymentId) => {
  const existing = await getReceiptByPaymentId(paymentId);
  if (existing) return existing;
  const { data, error } = await supabase
    .from('receipts')
    .insert({ payment_id: paymentId })
    .select('*')
    .single();
  if (error?.code === '23505') return getReceiptByPaymentId(paymentId);
  if (error) throw error;
  return data;
};

export default {
  getBookingById,
  getProviderByUserId,
  getUserById,
  getPaymentById,
  getPaymentByBookingAndPurpose,
  updateBookingPaymentState,
  createPayout,
  getPayoutByBookingId,
  createPayment,
  getPaymentByIdempotencyKey,
  getActivePayment,
  applyPayfastPayment,
  updatePayment,
  listBookingIdsForCustomer,
  listBookingIdsForProvider,
  listPayments,
  getReceiptByPaymentId,
  createReceipt
};
