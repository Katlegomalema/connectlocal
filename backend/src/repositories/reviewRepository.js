/**
 * Review Repository
 * Database operations for reviews and provider ratings
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { ConflictError, NotFoundError } from '../utils/errors.js';

export const getBookingById = async (bookingId) => {
  const { data, error } = await supabase
    .from('bookings')
    .select('id, customer_id, provider_id, status, balance_status')
    .eq('id', bookingId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Booking not found');
  return data;
};

export const getProviderById = async (providerId) => {
  const { data, error } = await supabase
    .from('providers')
    .select('id, user_id, rating_average, rating_count')
    .eq('id', providerId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Provider not found');
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

export const getReviewById = async (reviewId) => {
  const { data, error } = await supabase
    .from('reviews')
    .select('*')
    .eq('id', reviewId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Review not found');
  return data;
};

export const createReview = async (review) => {
  const { data, error } = await supabase
    .from('reviews')
    .insert(review)
    .select('*')
    .single();

  if (error?.code === '23505') throw new ConflictError('This booking already has a review');
  if (error) throw error;
  return data;
};

export const updateReview = async (reviewId, customerId, updates) => {
  const { data, error } = await supabase
    .from('reviews')
    .update(updates)
    .eq('id', reviewId)
    .eq('customer_id', customerId)
    .select('*')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Review not found');
  return data;
};

export const replyToReview = async (reviewId, providerId, providerResponse) => {
  const { data, error } = await supabase
    .from('reviews')
    .update({ provider_response_text: providerResponse, provider_response_at: new Date().toISOString() })
    .eq('id', reviewId)
    .eq('provider_id', providerId)
    .select('*')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Review not found for this provider');
  return data;
};

export const deleteReview = async (reviewId, customerId) => {
  const { data, error } = await supabase
    .from('reviews')
    .delete()
    .eq('id', reviewId)
    .eq('customer_id', customerId)
    .select('provider_id')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Review not found');
  return data;
};

export const hideReview = async (reviewId) => {
  const { data, error } = await supabase
    .from('reviews')
    .update({ is_flagged: true })
    .eq('id', reviewId)
    .select('*')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Review not found');
  return data;
};

export const refreshProviderRating = async (providerId) => {
  const ratings = [];
  let offset = 0;
  const batchSize = 1000;

  for (;;) {
    // eslint-disable-next-line no-await-in-loop -- paging: each batch depends on the previous one
    const { data, error } = await supabase
      .from('reviews')
      .select('rating')
      .eq('provider_id', providerId)
      .eq('is_flagged', false)
      .range(offset, offset + batchSize - 1);

    if (error) throw error;
    ratings.push(...(data || []));
    if (!data || data.length < batchSize) break;
    offset += batchSize;
  }

  const reviewCount = ratings.length;
  const averageRating = reviewCount
    ? Math.round((ratings.reduce((sum, review) => sum + Number(review.rating), 0) / reviewCount) * 10) / 10
    : 0;
  const { error } = await supabase
    .from('providers')
    .update({ rating_average: averageRating, rating_count: reviewCount })
    .eq('id', providerId);

  if (error) throw error;
  return { averageRating, reviewCount };
};

export const listVisibleReviews = async (providerId, page, limit) => {
  const offset = (page - 1) * limit;
  const { data, error, count } = await supabase
    .from('reviews')
    .select('id, booking_id, customer_id, provider_id, rating, review_text, provider_response_text, provider_response_at, created_at, '
      + 'customer:users(full_name), booking:bookings(service:services(service_name))', { count: 'exact' })
    .eq('provider_id', providerId)
    .eq('is_flagged', false)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  const provider = await getProviderById(providerId);
  return {
    reviews: data || [],
    averageRating: Number(provider.rating_average) || 0,
    totalReviews: count || 0,
    page,
    pages: Math.ceil((count || 0) / limit)
  };
};

export const listAllReviews = async ({ moderationStatus, page, limit }) => {
  let query = supabase
    .from('reviews')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false });
  if (moderationStatus === 'visible') query = query.eq('is_flagged', false);
  if (moderationStatus === 'hidden') query = query.eq('is_flagged', true);

  const offset = (page - 1) * limit;
  const { data, error, count } = await query.range(offset, offset + limit - 1);
  if (error) throw error;
  return {
    reviews: data || [],
    total: count || 0,
    page,
    pages: Math.ceil((count || 0) / limit)
  };
};

export const reportReview = async (reviewId) => {
  const { data, error } = await supabase
    .from('reviews')
    .update({ is_flagged: true })
    .eq('id', reviewId)
    .select('*')
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new NotFoundError('Review not found');
  return data;
};

export default {
  getBookingById,
  getProviderById,
  getProviderByUserId,
  getReviewById,
  createReview,
  updateReview,
  replyToReview,
  deleteReview,
  hideReview,
  reportReview,
  refreshProviderRating,
  listVisibleReviews,
  listAllReviews
};
