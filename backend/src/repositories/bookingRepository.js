/**
 * Booking Repository
 * Database operations for bookings
 */

import { supabase } from '../config/supabase.js';
import logger from '../utils/logger.js';
import { NotFoundError } from '../utils/errors.js';

/**
 * Fetch booking by ID
 */
export const getBookingById = async (bookingId) => {
  try {
    const { data, error } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', bookingId)
      .single();

    if (error) {
      throw new NotFoundError('Booking not found');
    }

    return data;
  } catch (error) {
    logger.error('Error fetching booking:', error);
    throw error;
  }
};

/**
 * Create new booking
 */
export const createBooking = async (bookingData) => {
  try {
    const { data, error } = await supabase
      .from('bookings')
      .insert([bookingData])
      .select()
      .single();

    if (error) throw error;

    return data;
  } catch (error) {
    logger.error('Error creating booking:', error);
    throw error;
  }
};

/**
 * Update booking
 */
export const updateBooking = async (bookingId, updates) => {
  try {
    const { data, error } = await supabase
      .from('bookings')
      .update(updates)
      .eq('id', bookingId)
      .select()
      .single();

    if (error) throw error;

    return data;
  } catch (error) {
    logger.error('Error updating booking:', error);
    throw error;
  }
};

/**
 * List user's bookings
 */
export const listUserBookings = async (userId, filters = {}, page = 1, limit = 20) => {
  try {
    let query = supabase
      .from('bookings')
      .select('*', { count: 'exact' })
      .eq('customer_id', userId);

    if (filters.status) {
      query = query.eq('status', filters.status);
    }

    const offset = (page - 1) * limit;
    const { data, error, count } = await query
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) throw error;

    return {
      data,
      total: count,
      page,
      pages: Math.ceil(count / limit)
    };
  } catch (error) {
    logger.error('Error listing bookings:', error);
    throw error;
  }
};

export default {
  getBookingById,
  createBooking,
  updateBooking,
  listUserBookings
};
