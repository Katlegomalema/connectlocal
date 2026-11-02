/**
 * Booking Repository
 * Database operations for bookings
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { ConflictError, NotFoundError } from '../utils/errors.js';

const throwDatabaseError = (error) => {
  if (error.code === '23P01' || error.code === '23505') {
    throw new ConflictError('The provider time slot is no longer available');
  }
  throw error;
};

export const getBookingById = async (bookingId) => {
  const { data, error } = await supabase
    .from('bookings')
    .select('*')
    .eq('id', bookingId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Booking not found');
  return data;
};

export const getServiceById = async (serviceId) => {
  const { data, error } = await supabase
    .from('services')
    .select('id, provider_id, base_price, duration_minutes, active, min_notice_hours')
    .eq('id', serviceId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Service not found');
  return data;
};

export const getProviderById = async (providerId) => {
  const { data, error } = await supabase
    .from('providers')
    .select('id, user_id, verification_status, is_active')
    .eq('id', providerId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Provider not found');
  return data;
};

export const getProviderByUserId = async (userId) => {
  const { data, error } = await supabase
    .from('providers')
    .select('id, user_id, verification_status, is_active')
    .eq('user_id', userId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Provider profile not found');
  return data;
};

export const hasBookingConflict = async (providerId, scheduledStart, scheduledEnd, excludeBookingId) => {
  let query = supabase
    .from('bookings')
    .select('id')
    .eq('provider_id', providerId)
    .in('status', ['pending', 'accepted', 'in_progress'])
    .lt('scheduled_start', scheduledEnd)
    .gt('scheduled_end', scheduledStart)
    .limit(1);

  if (excludeBookingId) query = query.neq('id', excludeBookingId);

  const { data, error } = await query;
  if (error) throw error;
  return Boolean(data?.length);
};

export const createBooking = async (bookingData) => {
  const { data, error } = await supabase
    .from('bookings')
    .insert(bookingData)
    .select('*')
    .single();

  if (error) throwDatabaseError(error);
  return data;
};

export const updateBooking = async (bookingId, allowedStatuses, updates) => {
  const { data, error } = await supabase
    .from('bookings')
    .update(updates)
    .eq('id', bookingId)
    .in('status', allowedStatuses)
    .select('*')
    .maybeSingle();

  if (error) throwDatabaseError(error);
  if (!data) throw new ConflictError('Booking status changed; reload and try again');
  return data;
};

export const listBookings = async ({ customerId, providerId, status, page, limit }) => {
  let query = supabase
    .from('bookings')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false });

  if (customerId) query = query.eq('customer_id', customerId);
  if (providerId) query = query.eq('provider_id', providerId);
  if (status) query = query.eq('status', status);

  const offset = (page - 1) * limit;
  const { data, error, count } = await query.range(offset, offset + limit - 1);
  if (error) throw error;

  return {
    bookings: data || [],
    total: count || 0,
    page,
    pages: Math.ceil((count || 0) / limit)
  };
};

export default {
  getBookingById,
  getServiceById,
  getProviderById,
  getProviderByUserId,
  hasBookingConflict,
  createBooking,
  updateBooking,
  listBookings
};