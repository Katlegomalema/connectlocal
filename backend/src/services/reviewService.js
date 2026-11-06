/**
 * Review Service
 * Review creation, provider replies, and moderation
 */

import * as reviewRepository from '../repositories/reviewRepository.js';
import { notifyBookingEvent } from './bookingNotifier.js';
import { AuthorizationError, ConflictError, ValidationError } from '../utils/errors.js';

const parsePagination = (pageValue, limitValue) => {
  const page = Number.parseInt(pageValue, 10) || 1;
  const limit = Number.parseInt(limitValue, 10) || 20;
  if (!Number.isInteger(page) || !Number.isInteger(limit) || page < 1 || limit < 1 || limit > 100) {
    throw new ValidationError('page must be positive and limit must be between 1 and 100');
  }
  return { page, limit };
};

export const createReview = async (actor, { bookingId, rating, comment }) => {
  if (actor?.role !== 'customer') throw new AuthorizationError('Only customers can submit reviews');
  if (!bookingId || !Number.isInteger(Number(rating)) || Number(rating) < 1 || Number(rating) > 5) {
    throw new ValidationError('bookingId and a rating from 1 to 5 are required');
  }
  if (comment != null && (typeof comment !== 'string' || comment.length > 500)) {
    throw new ValidationError('Review comment cannot exceed 500 characters');
  }

  const booking = await reviewRepository.getBookingById(bookingId);
  if (booking.customer_id !== actor.id) throw new AuthorizationError('You do not own this booking');
  if (booking.status !== 'completed') throw new ConflictError('Only completed bookings can be reviewed');
  // Business rule: review allowed only after the balance is paid.
  if (booking.balance_status !== 'paid') throw new ConflictError('You can review once the balance is paid');

  const review = await reviewRepository.createReview({
    booking_id: booking.id,
    customer_id: actor.id,
    provider_id: booking.provider_id,
    rating: Number(rating),
    review_text: comment?.trim() || null,
    is_flagged: false
  });
  await reviewRepository.refreshProviderRating(booking.provider_id);
  await notifyBookingEvent('reviewed', booking.id, { rating: Number(rating) });
  return review;
};

/** Public view of a review: the customer's first name only (no ids, no surname). */
export const publicReview = (review) => ({
  id: review.id,
  bookingId: review.booking_id,
  rating: review.rating,
  comment: review.review_text,
  customerFirstName: String(review.customer?.full_name || 'Customer').trim().split(/\s+/)[0],
  serviceName: review.booking?.service?.service_name ?? null,
  providerResponse: review.provider_response_text,
  providerResponseAt: review.provider_response_at,
  createdAt: review.created_at
});

export const getProviderReviews = async (providerId, pageValue, limitValue) => {
  const { page, limit } = parsePagination(pageValue, limitValue);
  const result = await reviewRepository.listVisibleReviews(providerId, page, limit);
  return { ...result, reviews: result.reviews.map(publicReview) };
};

export const updateReview = async (actor, reviewId, { rating, comment }) => {
  const review = await reviewRepository.getReviewById(reviewId);
  if (review.customer_id !== actor.id) throw new AuthorizationError('You can only edit your own review');
  const updates = {};
  if (rating !== undefined) {
    const numericRating = Number(rating);
    if (!Number.isInteger(numericRating) || numericRating < 1 || numericRating > 5) {
      throw new ValidationError('rating must be an integer from 1 to 5');
    }
    updates.rating = numericRating;
  }
  if (comment !== undefined) {
    if (typeof comment !== 'string' || comment.length > 500) {
      throw new ValidationError('comment must be a string of at most 500 characters');
    }
    updates.review_text = comment.trim() || null;
  }
  if (Object.keys(updates).length === 0) throw new ValidationError('rating or comment is required');

  const updated = await reviewRepository.updateReview(reviewId, actor.id, updates);
  await reviewRepository.refreshProviderRating(updated.provider_id);
  return updated;
};

export const replyToReview = async (actor, reviewId, response) => {
  if (typeof response !== 'string' || !response.trim() || response.length > 500) {
    throw new ValidationError('response must contain between 1 and 500 characters');
  }
  const provider = await reviewRepository.getProviderByUserId(actor.id);
  const review = await reviewRepository.getReviewById(reviewId);
  if (review.provider_id !== provider.id) throw new AuthorizationError('You cannot reply to this review');
  return reviewRepository.replyToReview(reviewId, provider.id, response.trim());
};

export const deleteReview = async (actor, reviewId) => {
  const review = await reviewRepository.getReviewById(reviewId);
  if (review.customer_id !== actor.id) throw new AuthorizationError('You can only delete your own review');
  const deleted = await reviewRepository.deleteReview(reviewId, actor.id);
  await reviewRepository.refreshProviderRating(deleted.provider_id);
};

export const listReviewsForModeration = async (filters) => {
  const { page, limit } = parsePagination(filters.page, filters.limit);
  return reviewRepository.listAllReviews({
    moderationStatus: filters.status,
    page,
    limit
  });
};

export const hideReview = async (reviewId) => {
  const review = await reviewRepository.hideReview(reviewId);
  await reviewRepository.refreshProviderRating(review.provider_id);
  return review;
};

export const reportReview = async (actor, reviewId) => {
  if (!actor?.id) throw new AuthorizationError('Authentication required');
  const review = await reviewRepository.reportReview(reviewId);
  await reviewRepository.refreshProviderRating(review.provider_id);
  return review;
};

export default {
  createReview,
  getProviderReviews,
  updateReview,
  replyToReview,
  deleteReview,
  listReviewsForModeration,
  hideReview,
  reportReview
};
