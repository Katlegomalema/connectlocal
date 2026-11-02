/**
 * Admin Routes
 * Handles administrative functions and platform management
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken, requireRole } from '../middleware/auth.js';
import { validateBody } from '../middleware/validation.js';
import * as adminService from '../services/adminService.js';

const router = express.Router();
const updateUserSchema = z.object({ status: z.enum(['active', 'suspended', 'deactivated']) }).strict();

// Middleware: Ensure user is admin
router.use(verifyToken, requireRole('admin'));

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
router.get('/providers/pending', asyncHandler(async (req, res) => {
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
router.post('/providers/:id/reject', asyncHandler(async (req, res) => {
  const provider = await adminService.decideProviderVerification(req.user, req.params.id, 'reject');
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
 * Query params: from, to, metrics
 */
router.get('/analytics', asyncHandler(async (req, res) => {
  const analytics = await adminService.getAnalytics(req.user);
  res.status(200).json({
    success: true,
    data: analytics
  });
}));

/**
 * GET /api/v1/admin/disputes
 * List active disputes
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
router.put('/disputes/:id', asyncHandler(async (req, res) => {
  const dispute = await adminService.resolveDispute(req.user, req.params.id, req.body);
  res.status(200).json({ success: true, message: 'Dispute resolved', data: dispute });
}));

export default router;
