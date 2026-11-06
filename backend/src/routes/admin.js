/**
 * Admin Routes
 * Handles administrative functions and platform management
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken, requireRole } from '../middleware/auth.js';
import { validateBody, validateUuidParam } from '../middleware/validation.js';
import * as adminService from '../services/adminService.js';

const router = express.Router();
const rejectSchema = z.object({ reason: z.string().trim().min(3).max(1000) }).strict();
const updateUserSchema = z.object({ status: z.enum(['active', 'suspended', 'deactivated']) }).strict();
const disputeUpdateSchema = z.object({
  status: z.enum(['under_review', 'resolved', 'rejected']).default('resolved'),
  resolutionNotes: z.string().max(5000).optional()
}).strict();

// Middleware: Ensure user is admin
router.use(verifyToken, requireRole('admin'));
router.param('id', validateUuidParam);

/**
 * GET /api/v1/admin/users
 * List all users with filtering
 * Query params: role, status, page, limit
 */
router.get('/users', asyncHandler(async (req, res) => {
  const result = await adminService.listUsers(req.user, req.query);
  res.status(200).json({
    success: true,
    data: result
  });
}));

/**
 * PUT /api/v1/admin/users/:id
 * Update user account (suspend, activate, etc.)
 */
router.put('/users/:id', validateBody(updateUserSchema), asyncHandler(async (req, res) => {
  const user = await adminService.updateUserAccount(req.user, req.params.id, req.validatedBody.status);
  res.status(200).json({
    success: true,
    message: 'User updated successfully',
    data: { user }
  });
}));

/**
 * GET /api/v1/admin/providers/pending
 * List pending provider verification requests
 * Query params: page, limit
 */
/** GET /providers/pending?status=pending|verified|rejected  (default pending = submitted, oldest first) */
router.get('/providers/pending', asyncHandler(async (req, res) => {
  res.set('Cache-Control', 'no-store'); // contains signed document links
  const result = await adminService.listPendingProviders(req.user, req.query);
  res.status(200).json({
    success: true,
    data: result
  });
}));

/**
 * POST /api/v1/admin/providers/:id/verify
 * Approve a provider verification
 */
router.post('/providers/:id/verify', asyncHandler(async (req, res) => {
  const provider = await adminService.decideProviderVerification(req.user, req.params.id, 'approve');
  res.status(200).json({
    success: true,
    message: 'Provider verified successfully',
    data: { provider }
  });
}));

/**
 * POST /api/v1/admin/providers/:id/reject
 * Reject a provider verification
 */
router.post('/providers/:id/reject', validateBody(rejectSchema), asyncHandler(async (req, res) => {
  const provider = await adminService.decideProviderVerification(req.user, req.params.id, 'reject', req.validatedBody.reason);
  res.status(200).json({
    success: true,
    message: 'Provider verification rejected',
    data: { provider }
  });
}));

/**
 * GET /api/v1/admin/reviews
 * List flagged/reported reviews
 * Query params: page, limit, status
 */
router.get('/reviews', asyncHandler(async (req, res) => {
  const result = await adminService.listReviews(req.user, req.query);
  res.status(200).json({
    success: true,
    data: result
  });
}));

/**
 * POST /api/v1/admin/reviews/:id/hide
 * Hide a review
 */
router.post('/reviews/:id/hide', asyncHandler(async (req, res) => {
  const review = await adminService.hideReview(req.user, req.params.id);
  res.status(200).json({
    success: true,
    message: 'Review hidden',
    data: { review }
  });
}));

/**
 * GET /api/v1/admin/analytics
 * Get platform analytics
 */
router.get('/analytics', asyncHandler(async (req, res) => {
  const analytics = await adminService.getAnalytics(req.user);
  res.status(200).json({
    success: true,
    data: analytics
  });
}));

/** GET /api/v1/admin/bookings?status=&page=&limit=  every booking, newest first */
router.get('/bookings', asyncHandler(async (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, data: await adminService.listBookings(req.user, req.query) });
}));

/** GET /api/v1/admin/payments?page=&limit=  every payment (fees and balances, card and cash) */
router.get('/payments', asyncHandler(async (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, data: await adminService.listPayments(req.user, req.query) });
}));

/** GET /api/v1/admin/payouts?page=&limit=  every payout, bank details masked */
router.get('/payouts', asyncHandler(async (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, data: await adminService.listPayouts(req.user, req.query) });
}));

/**
 * GET /api/v1/admin/disputes
 * List active disputes by default, or filter by status
 * Query params: page, limit, status
 */
router.get('/disputes', asyncHandler(async (req, res) => {
  const disputes = await adminService.listDisputes(req.user, req.query);
  res.status(200).json({ success: true, data: disputes });
}));

/**
 * PUT /api/v1/admin/disputes/:id
 * Resolve a dispute
 */
router.put('/disputes/:id', validateBody(disputeUpdateSchema), asyncHandler(async (req, res) => {
  const dispute = await adminService.resolveDispute(req.user, req.params.id, req.validatedBody);
  res.status(200).json({ success: true, message: 'Dispute resolved', data: dispute });
}));

export default router;
