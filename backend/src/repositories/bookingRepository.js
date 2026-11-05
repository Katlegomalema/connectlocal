/**
 * Booking Repository
 * Database operations for bookings
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { ConflictError, NotFoundError } from '../utils/errors.js';

/** Booking + what the screens show: service name, business name, customer name/phone. */
const BOOKING_SELECT = '*, service:services(service_name), provider:providers(business_name, user_id), '
  + 'customer:users!bookings_customer_id_fkey(full_name, phone_number), review:reviews(id, rating, review_text)';

const throwDatabaseError = (error) => {
  if (error.code === '23P01' || error.code === '23505') {
    throw new ConflictError('The provider time slot is no longer available');
  }
  throw error;
};

export const getBookingById = async (bookingId) => {
  const { data, error } = await supabase
    .from('bookings')
    .select(BOOKING_SELECT)
    .eq('id', bookingId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Booking not found');
  return data;
};

export const getServiceById = async (serviceId) => {
  const { data, error } = await supabase
    .from('services')
    .select('id, provider_id, base_price, duration_minutes, active, min_notice_hours, pricing_type')
    .eq('id', serviceId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Service not found');
  return data;
};

export const getProviderById = async (providerId) => {
  const { data, error } = await supabase
    .from('providers')
    .select('id, user_id, verification_status, is_active, offers_visit, offers_house_call, slot_minutes, '
      + 'street_address, suburb, city, location')
    .eq('id', providerId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Provider not found');
  return data;
};

export const getPackageById = async (packageId) => {
  const { data, error } = await supabase
    .from('service_packages')
    .select('id, service_id, name, price, duration_minutes, is_active')
    .eq('id', packageId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Package not found');
  return data;
};

/** Verification flags needed before a customer may book. */
export const getCustomerById = async (userId) => {
  const { data, error } = await supabase
    .from('users')
    .select('id, role, email_verified, phone_verified, is_active, deleted_at')
    .eq('id', userId)
    .maybeSingle();

  if (error) throw error;
  if (!data || !data.is_active || data.deleted_at) throw new NotFoundError('User not found');
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

/** How long an unpaid request holds its time slot (the PayFast checkout link lives 30 minutes). */
export const UNPAID_HOLD_MINUTES = 30;

export const hasBookingConflict = async (providerId, scheduledStart, scheduledEnd, excludeBookingId) => {
  const holdSince = new Date(Date.now() - UNPAID_HOLD_MINUTES * 60000).toISOString();
  let query = supabase
    .from('bookings')
    .select('id')
    .eq('provider_id', providerId)
    .in('status', ['pending', 'accepted', 'in_progress'])
    // A pending request only blocks the slot once its fee is paid, or while its checkout is still open.
    .or(`status.neq.pending,booking_fee_status.eq.paid,created_at.gt.${holdSince}`)
    .lt('scheduled_start', scheduledEnd)
    .gt('scheduled_end', scheduledStart)
    .limit(1);

  if (excludeBookingId) query = query.neq('id', excludeBookingId);

  const { data, error } = await query;
  if (error) throw error;
  return Boolean(data?.length);
};

/** The provider's working hours (provider_availability rows, day_of_week 0 = Sunday). */
export const getProviderAvailability = async (providerId) => {
  const { data, error } = await supabase
    .from('provider_availability')
    .select('day_of_week, start_time, end_time')
    .eq('provider_id', providerId);
  if (error) throw error;
  return data || [];
};

/** Times held by this provider's bookings between [fromIso] and [toIso] (same rule as hasBookingConflict). */
export const listBusyTimes = async (providerId, fromIso, toIso) => {
  const holdSince = new Date(Date.now() - UNPAID_HOLD_MINUTES * 60000).toISOString();
  const { data, error } = await supabase
    .from('bookings')
    .select('scheduled_start, scheduled_end')
    .eq('provider_id', providerId)
    .in('status', ['pending', 'accepted', 'in_progress'])
    .or(`status.neq.pending,booking_fee_status.eq.paid,created_at.gt.${holdSince}`)
    .lt('scheduled_start', toIso)
    .gt('scheduled_end', fromIso)
    .order('scheduled_start')
    .limit(500);
  if (error) throw error;
  return data || [];
};

export const createBooking = async (bookingData) => {
  const { data, error } = await supabase
    .from('bookings')
    .insert(bookingData)
    .select(BOOKING_SELECT)
    .single();

  if (error) throwDatabaseError(error);
  return data;
};

export const updateBooking = async (bookingId, allowedStatuses, updates, expected = {}) => {
  let query = supabase
    .from('bookings')
    .update(updates)
    .eq('id', bookingId)
    .in('status', allowedStatuses);
  // Optimistic concurrency: only update if these columns still have the values we read.
  for (const [column, value] of Object.entries(expected)) query = query.eq(column, value);

  const { data, error } = await query.select(BOOKING_SELECT).maybeSingle();

  if (error) throwDatabaseError(error);
  if (!data) throw new ConflictError('Booking status changed; reload and try again');
  return data;
};

export const listBookings = async ({
  customerId, providerId, status, page, limit
}) => {
  let query = supabase
    .from('bookings')
    .select(BOOKING_SELECT, { count: 'exact' })
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
  listBusyTimes,
  getProviderAvailability,
  getBookingById,
  getServiceById,
  getProviderById,
  getPackageById,
  getCustomerById,
  getProviderByUserId,
  hasBookingConflict,
  createBooking,
  updateBooking,
  listBookings
};
