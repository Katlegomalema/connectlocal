/**
 * User Routes
 * Handles customer user profile management
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken, requireOwnership } from '../middleware/auth.js';
import { validateBody } from '../middleware/validation.js';
import * as userService from '../services/userService.js';

const router = express.Router();
const updateProfileSchema = z.object({
  fullName: z.string().min(2).max(150).optional(),
  phoneNumber: z.string().max(20).optional(),
  address: z.string().max(500).optional(),
  profilePhotoUrl: z.string().url().optional()
}).strict();
const avatarSchema = z.object({ avatarUrl: z.string().url() });

/**
 * GET /api/v1/users/:id
 * Fetch user profile by ID
 */
router.get('/:id', asyncHandler(async (req, res) => {
  const user = await userService.getUserProfile(req.params.id);
  res.status(200).json({
    success: true,
    data: { user }
  });
}));

/**
 * PUT /api/v1/users/:id
 * Update user profile
 */
router.put('/:id', verifyToken, requireOwnership('id'), validateBody(updateProfileSchema), asyncHandler(async (req, res) => {
  const user = await userService.updateUserProfile(req.user, req.params.id, req.validatedBody);
  res.status(200).json({
    success: true,
    message: 'Profile updated successfully',
    data: { user }
  });
}));

/**
 * GET /api/v1/users/:id/bookings
 * Fetch user's booking history
 */
router.get('/:id/bookings', verifyToken, requireOwnership('id'), asyncHandler(async (req, res) => {
  const bookings = await userService.getUserBookings(req.user, req.params.id, req.query.page, req.query.limit);
  res.status(200).json({
    success: true,
    data: bookings
  });
}));

/**
 * POST /api/v1/users/:id/avatar
 * Upload user profile photo
 */
router.post('/:id/avatar', verifyToken, requireOwnership('id'), validateBody(avatarSchema), asyncHandler(async (req, res) => {
  const user = await userService.updateAvatar(req.user, req.params.id, req.validatedBody.avatarUrl);
  res.status(200).json({
    success: true,
    message: 'Avatar updated successfully',
     data: { avatarUrl: user.profile_image }
  });
}));

/**
 * DELETE /api/v1/users/:id
 * Delete user account
 */
router.delete('/:id', verifyToken, requireOwnership('id'), asyncHandler(async (req, res) => {
  await userService.deleteUserProfile(req.user, req.params.id);
  res.status(200).json({
    success: true,
    message: 'Account deactivated successfully'
  });
}));

export default router;
