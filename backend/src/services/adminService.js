/**
 * Admin Service
 * Administrative workflows supported by the current database schema
 */

import * as adminRepository from '../repositories/adminRepository.js';
import * as userRepository from '../repositories/userRepository.js';
import * as reviewRepository from '../repositories/reviewRepository.js';
import * as reviewService from './reviewService.js';
import { AppError, AuthorizationError, ValidationError } from '../utils/errors.js';

const requireAdmin = (actor) => {
  if (actor?.role !== 'admin') throw new AuthorizationError('Administrator access is required');
};

const parsePagination = (pageValue, limitValue) => {
  const page = Number.parseInt(pageValue, 10) || 1;
  const limit = Number.parseInt(limitValue, 10) || 20;
  if (!Number.isInteger(page) || !Number.isInteger(limit) || page < 1 || limit < 1 || limit > 100) {
    throw new ValidationError('page must be positive and limit must be between 1 and 100');
  }
  return { page, limit };
};

export const listUsers = async (actor, filters = {}) => {
  requireAdmin(actor);
  const { page, limit } = parsePagination(filters.page, filters.limit);
  if (filters.role && !['customer', 'provider', 'admin'].includes(filters.role)) {
    throw new ValidationError('Invalid user role filter');
  }
  if (filters.status && !['active', 'suspended', 'deactivated'].includes(filters.status)) {
    throw new ValidationError('Invalid account status filter');
  }
  const result = await userRepository.listUsers(filters, page, limit);
  return { users: result.data, total: result.total, page: result.page, pages: result.pages };
};

export const updateUserAccount = async (actor, userId, status) => {
  requireAdmin(actor);
  if (!['active', 'suspended', 'deactivated'].includes(status)) {
    throw new ValidationError('status must be active, suspended, or deactivated');
  }
  if (actor.id === userId && status !== 'active') {
    throw new ValidationError('Administrators cannot suspend or deactivate their own account');
  }
  const user = await userRepository.updateUser(userId, { account_status: status });
  return { id: user.id, role: user.role, account_status: user.account_status };
};

export const listPendingProviders = async (actor, filters = {}) => {
  requireAdmin(actor);
  const { page, limit } = parsePagination(filters.page, filters.limit);
  return adminRepository.listProvidersByVerificationStatus('pending', page, limit);
};

export const decideProviderVerification = async (actor, providerId, decision) => {
  requireAdmin(actor);
  if (!['approve', 'reject'].includes(decision)) throw new ValidationError('decision must be approve or reject');
  return adminRepository.setProviderVerificationStatus(
    providerId,
    'pending',
    decision === 'approve' ? 'approved' : 'rejected'
  );
};

export const listReviews = async (actor, filters = {}) => {
  requireAdmin(actor);
  if (filters.status && !['visible', 'hidden'].includes(filters.status)) {
    throw new ValidationError('Review status must be visible or hidden');
  }
  return reviewService.listReviewsForModeration(filters);
};

export const hideReview = async (actor, reviewId) => {
  requireAdmin(actor);
  return reviewRepository.hideReview(reviewId).then(async (review) => {
    await reviewRepository.refreshProviderRating(review.provider_id);
    return review;
  });
};

export const getAnalytics = async (actor) => {
  requireAdmin(actor);
  const [totalUsers, totalProviders, totalBookings, totalRevenue, averageRating] = await Promise.all([
    adminRepository.countRows('users', { deleted_at: null }),
    adminRepository.countRows('providers', { deleted_at: null }),
    adminRepository.countRows('bookings'),
    adminRepository.getPaidRevenue(),
    adminRepository.getAverageProviderRating()
  ]);
  return { totalUsers, totalProviders, totalBookings, totalRevenue, averageRating };
};

export const listDisputes = async () => {
  throw new AppError('Disputes are unavailable until a disputes table is added', 501, 'NOT_IMPLEMENTED');
};

export const resolveDispute = async () => {
  throw new AppError('Disputes are unavailable until a disputes table is added', 501, 'NOT_IMPLEMENTED');
};

export default {
  listUsers,
  updateUserAccount,
  listPendingProviders,
  decideProviderVerification,
  listReviews,
  hideReview,
  getAnalytics,
  listDisputes,
  resolveDispute
};