/**
 * Admin Service
 * Administrative workflows supported by the current database schema
 */

import * as adminRepository from '../repositories/adminRepository.js';
import * as reviewRepository from '../repositories/reviewRepository.js';
import * as reviewService from './reviewService.js';
import * as notificationService from './notificationService.js';
import * as storage from '../integrations/storage.js';
import logger from '../utils/logger.js';
import { toLatLng } from '../utils/geo.js';
import { COMMISSION_RATE } from '../config/business.js';
import { AuthorizationError, ValidationError } from '../utils/errors.js';

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
  const result = await adminRepository.listUsersWithBusiness({
    role: filters.role, status: filters.status, query: filters.q, page, limit
  });
  return {
    users: result.rows.map((user) => {
      const business = Array.isArray(user.business) ? user.business[0] : user.business;
      let status = 'active';
      if (user.deleted_at) status = 'deactivated';
      else if (!user.is_active) status = 'suspended';
      return {
        id: user.id,
        fullName: user.full_name,
        email: user.email,
        phoneNumber: user.phone_number,
        role: user.role,
        status,
        emailVerified: user.email_verified,
        phoneVerified: user.phone_verified,
        createdAt: user.created_at,
        business: business
          ? { id: business.id, name: business.business_name, verificationStatus: business.verification_status }
          : null
      };
    }),
    total: result.total,
    page: result.page,
    pages: result.pages
  };
};

export const updateUserAccount = async (actor, userId, status) => {
  requireAdmin(actor);
  if (!['active', 'suspended', 'deactivated'].includes(status)) {
    throw new ValidationError('status must be active, suspended, or deactivated');
  }
  if (actor.id === userId && status !== 'active') {
    throw new ValidationError('Administrators cannot suspend or deactivate their own account');
  }
  const user = await adminRepository.updateUserAccount(userId, status);
  return {
    id: user.id, role: user.role, status: user.status, is_active: user.is_active
  };
};

const groupBy = (rows, key) => rows.reduce((map, row) => {
  map.set(row[key], [...(map.get(row[key]) || []), row]);
  return map;
}, new Map());

/** Documents for the admin: private files get a short-lived signed link; paths are never sent. */
const documentForAdmin = async (document) => ({
  id: document.id,
  documentType: document.document_type,
  status: document.approval_status,
  uploadedAt: document.uploaded_at,
  url: document.storage_path
    ? await storage.signedViewUrl(storage.BUCKETS.documents, document.storage_path)
    : document.document_url,
  urlExpiresInSeconds: document.storage_path ? 600 : null
});

const pointToLatLng = (location) => toLatLng(location);

export const listPendingProviders = async (actor, filters = {}) => {
  requireAdmin(actor);
  const { page, limit } = parsePagination(filters.page, filters.limit);
  const status = filters.status || 'pending';
  if (!['pending', 'verified', 'rejected'].includes(status)) throw new ValidationError('Invalid status filter');

  const result = await adminRepository.listProvidersByVerificationStatus(status, page, limit);
  const ids = result.providers.map(({ id }) => id);
  const [documents, gallery] = await Promise.all([
    adminRepository.listProviderDocuments(ids),
    adminRepository.listGalleryForProviders(ids)
  ]);
  const documentsByProvider = groupBy(documents, 'provider_id');
  const galleryByProvider = groupBy(gallery, 'provider_id');

  const providers = await Promise.all(result.providers.map(async (provider) => ({
    id: provider.id,
    businessName: provider.business_name,
    description: provider.business_description,
    registrationNumber: provider.business_registration_number,
    category: provider.category?.name ?? null,
    address: [provider.street_address, provider.suburb, provider.city, provider.province, provider.postal_code]
      .filter(Boolean).join(', ') || null,
    location: pointToLatLng(provider.location),
    status: provider.verification_status,
    rejectionReason: provider.rejection_reason,
    submittedAt: provider.submitted_at,
    reviewedAt: provider.reviewed_at,
    applicant: provider.applicant ? {
      id: provider.applicant.id,
      fullName: provider.applicant.full_name,
      email: provider.applicant.email,
      phoneNumber: provider.applicant.phone_number,
      phoneVerified: provider.applicant.phone_verified,
      emailVerified: provider.applicant.email_verified
    } : null,
    documents: await Promise.all((documentsByProvider.get(provider.id) || []).map(documentForAdmin)),
    photos: (galleryByProvider.get(provider.id) || []).map((photo) => ({ id: photo.id, url: photo.image_url }))
  })));

  return { ...result, providers };
};

/** Notifications must never undo the decision. */
const notifySafely = async (userId, notification) => {
  try {
    await notificationService.sendInAppNotification(userId, notification);
  } catch (error) {
    logger.warn({ err: error, userId }, 'Notification could not be sent');
  }
};

export const decideProviderVerification = async (actor, providerId, decision, reason) => {
  requireAdmin(actor);
  if (!['approve', 'reject'].includes(decision)) throw new ValidationError('decision must be approve or reject');
  const rejectionReason = typeof reason === 'string' ? reason.trim() : '';
  if (decision === 'reject' && (rejectionReason.length < 3 || rejectionReason.length > 1000)) {
    throw new ValidationError('Please give the applicant a reason (3 to 1000 characters)');
  }

  const approved = decision === 'approve';
  const provider = await adminRepository.setProviderVerificationStatus(providerId, 'pending', approved ? 'verified' : 'rejected', {
    reviewed_at: new Date().toISOString(),
    reviewed_by: actor.id,
    rejection_reason: approved ? null : rejectionReason
  });
  await adminRepository.setProviderDocumentsStatus(provider.id, approved ? 'approved' : 'rejected', actor.id, rejectionReason);

  await notifySafely(provider.user_id, approved ? {
    type: 'system',
    title: 'Your business is approved',
    body: `${provider.business_name} is verified. You can now add services and receive bookings.`,
    relatedEntityType: 'provider',
    relatedEntityId: provider.id
  } : {
    type: 'system',
    title: 'Your application needs changes',
    body: `Reason: ${rejectionReason}. Update your application and submit it again.`,
    relatedEntityType: 'provider',
    relatedEntityId: provider.id
  });
  return provider;
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
  const [
    totalUsers, totalProviders, verifiedProviders, totalBookings, totalRevenue, averageRating,
    commissionEarned, paidOut
  ] = await Promise.all([
    adminRepository.countRows('users', { deleted_at: null }),
    adminRepository.countRows('providers'),
    adminRepository.countRows('providers', { verification_status: 'verified' }),
    adminRepository.countRows('bookings'),
    adminRepository.getPaidRevenue(),
    adminRepository.getAverageProviderRating(),
    adminRepository.sumColumn('payouts', 'commission_amount', { status: 'paid' }),
    adminRepository.sumColumn('payouts', 'payout_amount', { status: 'paid' })
  ]);
  return {
    totalUsers,
    totalProviders,
    verifiedProviders,
    totalBookings,
    totalRevenue,
    averageRating,
    commissionRate: COMMISSION_RATE,
    commissionEarned,
    paidOut
  };
};

const ADMIN_BOOKING_STATUSES = ['pending', 'accepted', 'in_progress', 'completed', 'cancelled', 'rejected'];

/** Every booking (newest first). Admins see the customer phone; never the PIN hash. */
export const listBookings = async (actor, filters = {}) => {
  requireAdmin(actor);
  const { page, limit } = parsePagination(filters.page, filters.limit);
  if (filters.status && !ADMIN_BOOKING_STATUSES.includes(filters.status)) {
    throw new ValidationError('Invalid booking status');
  }
  const result = await adminRepository.listAllBookings({ status: filters.status, page, limit });
  return {
    bookings: result.rows.map((row) => {
      const copy = { ...row, service_location: toLatLng(row.service_location) };
      delete copy.arrival_pin_hash;
      return copy;
    }),
    total: result.total,
    page,
    pages: result.pages
  };
};

const bookingNames = (booking) => ({
  serviceName: booking?.service?.service_name ?? null,
  businessName: booking?.provider?.business_name ?? null,
  customerName: booking?.customer?.full_name ?? null
});

export const listPayments = async (actor, filters = {}) => {
  requireAdmin(actor);
  const { page, limit } = parsePagination(filters.page, filters.limit);
  const result = await adminRepository.listAllPayments({ page, limit });
  return {
    payments: result.rows.map((p) => ({
      id: p.id,
      bookingId: p.booking_id,
      amount: Number(p.amount),
      currency: p.currency,
      purpose: p.purpose,
      method: p.method,
      status: p.payment_status,
      gateway: p.gateway_provider,
      reference: p.transaction_reference,
      refundedAmount: Number(p.refunded_amount || 0),
      paidAt: p.paid_at,
      createdAt: p.created_at,
      ...bookingNames(p.booking)
    })),
    total: result.total,
    page,
    pages: result.pages
  };
};

export const listPayouts = async (actor, filters = {}) => {
  requireAdmin(actor);
  const { page, limit } = parsePagination(filters.page, filters.limit);
  const result = await adminRepository.listAllPayouts({ page, limit });
  return {
    payouts: result.rows.map((p) => {
      const bank = Array.isArray(p.provider?.bank) ? p.provider.bank[0] : p.provider?.bank;
      return {
        id: p.id,
        bookingId: p.booking_id,
        providerId: p.provider_id,
        grossAmount: Number(p.gross_amount),
        commissionRate: Number(p.commission_rate),
        commissionAmount: Number(p.commission_amount),
        cashCollectedAmount: Number(p.cash_collected_amount),
        payoutAmount: Number(p.payout_amount),
        status: p.status,
        reference: p.payout_reference,
        note: p.failure_reason,
        paidAt: p.paid_at,
        createdAt: p.created_at,
        ...bookingNames(p.booking),
        businessName: p.provider?.business_name ?? null,
        // Masked: bank, holder, branch and the LAST 4 digits only.
        bank: bank
          ? {
            bankName: bank.bank_name,
            accountType: bank.account_type,
            accountHolderName: bank.account_holder_name,
            branchCode: bank.branch_code,
            accountLast4: bank.account_last4
          }
          : null
      };
    }),
    total: result.total,
    page,
    pages: result.pages
  };
};

export const listDisputes = async (actor, filters = {}) => {
  requireAdmin(actor);
  const { page, limit } = parsePagination(filters.page, filters.limit);
  if (filters.status && !['open', 'under_review', 'resolved', 'rejected'].includes(filters.status)) {
    throw new ValidationError('Invalid dispute status');
  }
  return adminRepository.listDisputes({ status: filters.status, page, limit });
};

export const resolveDispute = async (actor, disputeId, { status = 'resolved', resolutionNotes } = {}) => {
  requireAdmin(actor);
  if (!['under_review', 'resolved', 'rejected'].includes(status)) {
    throw new ValidationError('status must be under_review, resolved, or rejected');
  }
  if (resolutionNotes !== undefined && (typeof resolutionNotes !== 'string' || resolutionNotes.length > 5000)) {
    throw new ValidationError('resolutionNotes must be a string of at most 5000 characters');
  }
  if (['resolved', 'rejected'].includes(status) && !resolutionNotes?.trim()) {
    throw new ValidationError('resolutionNotes are required to resolve or reject a dispute');
  }
  return adminRepository.updateDispute(disputeId, status, resolutionNotes?.trim(), actor.id);
};

export default {
  listUsers,
  updateUserAccount,
  listPendingProviders,
  decideProviderVerification,
  listReviews,
  hideReview,
  getAnalytics,
  listBookings,
  listPayments,
  listPayouts,
  listDisputes,
  resolveDispute
};
