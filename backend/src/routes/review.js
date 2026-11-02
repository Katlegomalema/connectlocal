/**
 * Review Routes
 * Handles ratings, reviews, and review moderation
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken, requireRole } from '../middleware/auth.js';
import { validateBody } from '../middleware/validation.js';
import * as reviewService from '../services/reviewService.js';

const router = express.Router();
const createReviewSchema = z.object({
  bookingId: z.string().min(1),
  rating: z.coerce.number().int().min(1).max(5),
  comment: z.string().max(500).optional()
}).strict();
const updateReviewSchema = z.object({
  rating: z.coerce.number().int().min(1).max(5).optional(),
  comment: z.string().max(500).optional()
}).strict();
const replySchema = z.object({ response: z.string().min(1).max(500) }).strict();

/**
 * POST /api/v1/reviews
 * Create a new review/rating for a provider
 */
router.post('/', verifyToken, validateBody(createReviewSchema), asyncHandler(async (req, res) => {
  const review = await reviewService.createReview(req.user, req.validatedBody);
  res.status(201).json({
    success: true,
    message: 'Review submitted successfully',
    data: review
  });
}));

/**
 * GET /api/v1/reviews/:providerId
 * Fetch reviews for a provider
 * Query params: page, limit, sort
 */
router.get('/:providerId', asyncHandler(async (req, res) => {
  const result = await reviewService.getProviderReviews(req.params.providerId, req.query.page, req.query.limit);
  res.status(200).json({
    success: true,
    data: result
  });
}));

/**
 * PUT /api/v1/reviews/:id
 * Update a review
 */
router.put('/:id', verifyToken, validateBody(updateReviewSchema), asyncHandler(async (req, res) => {
  const review = await reviewService.updateReview(req.user, req.params.id, req.validatedBody);
  res.status(200).json({
    success: true,
    message: 'Review updated successfully',
    data: review
  });
}));

/**
 * POST /api/v1/reviews/:id/reply
 * Provider replies to a review
 */
router.post('/:id/reply', verifyToken, requireRole('provider', 'admin'), validateBody(replySchema), asyncHandler(async (req, res) => {
  const review = await reviewService.replyToReview(req.user, req.params.id, req.validatedBody.response);
  res.status(201).json({
    success: true,
    message: 'Reply added successfully',
    data: review
  });
}));

/**
 * DELETE /api/v1/reviews/:id
 * Delete a review (user can only delete their own)
 */
router.delete('/:id', verifyToken, asyncHandler(async (req, res) => {
  await reviewService.deleteReview(req.user, req.params.id);
  res.status(204).send();
}));

/**
 * POST /api/v1/reviews/:id/report
 * Report a review as inappropriate
 */
router.post('/:id/report', verifyToken, asyncHandler(async (req, res) => {
  const review = await reviewService.reportReview(req.user, req.params.id);
  res.status(201).json({
    success: true,
    message: 'Review flagged for moderation',
    data: { review }
  });
}));

export default router;
