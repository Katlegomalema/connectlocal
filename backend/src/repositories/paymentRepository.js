/**
 * Payment Repository
 * Database operations for booking payments
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { ConflictError, NotFoundError } from '../utils/errors.js';

export const getBookingById = async (bookingId) => {
  const { data, error } = await supabase
    .from('bookings')
    .select('id, customer_id, provider_id, status, total_amount')
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

export const getPaymentByBookingId = async (bookingId) => {
  const { data, error } = await supabase
    .from('payments')
    .select('*')
    .eq('booking_id', bookingId)
    .maybeSingle();

  if (error) throw error;
  return data;
};

export const createPayment = async (payment) => {
  const { data, error } = await supabase
    .from('payments')
    .insert(payment)
    .select('*')
    .single();

  if (error?.code === '23505') throw new ConflictError('A payment already exists for this booking');
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

export const listPayments = async ({ bookingIds, status, page, limit }) => {
  if (!bookingIds.length) return { payments: [], total: 0, page, pages: 0 };
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
  getPaymentByBookingId,
  createPayment,
  updatePayment,
  listBookingIdsForCustomer,
  listBookingIdsForProvider,
  listPayments,
  getReceiptByPaymentId,
  createReceipt
};