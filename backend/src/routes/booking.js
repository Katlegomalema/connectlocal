/**
 * Booking Routes
 * Handles booking creation, management, and status updates
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken } from '../middleware/auth.js';
import { validateBody } from '../middleware/validation.js';
import * as bookingService from '../services/bookingService.js';

const router = express.Router();
const createBookingSchema = z.object({
  providerId: z.string().min(1),
  serviceId: z.string().min(1),
  scheduledStart: z.string().min(1),
  notes: z.string().max(2000).optional()
});
const rescheduleSchema = z.object({ scheduledStart: z.string().min(1) });
const reasonSchema = z.object({ reason: z.string().max(1000).optional() });

/**
 * POST /api/v1/bookings
 * Create a new booking
 */
router.post('/', verifyToken, validateBody(createBookingSchema), asyncHandler(async (req, res) => {
  const booking = await bookingService.createBooking(req.user, req.validatedBody);
  res.status(201).json({
    success: true,
    message: 'Booking created successfully',
    data: booking
  });
}));

/**
 * GET /api/v1/bookings/:id
 * Fetch booking details
 */
router.get('/:id', verifyToken, asyncHandler(async (req, res) => {
  const booking = await bookingService.getBooking(req.user, req.params.id);
  res.status(200).json({
    success: true,
    data: booking
  });
}));

/**
 * PUT /api/v1/bookings/:id
 * Update booking (reschedule)
 */
router.put('/:id', verifyToken, validateBody(rescheduleSchema), asyncHandler(async (req, res) => {
  const booking = await bookingService.rescheduleBooking(
    req.user,
    req.params.id,
    req.validatedBody.scheduledStart
  );
  res.status(200).json({
    success: true,
    message: 'Booking updated successfully',
    data: booking
  });
}));

/**
 * POST /api/v1/bookings/:id/accept
 * Provider accepts a booking request
 */
router.post('/:id/accept', verifyToken, asyncHandler(async (req, res) => {
  const booking = await bookingService.acceptBooking(req.user, req.params.id);
  res.status(200).json({
    success: true,
    message: 'Booking accepted',
    data: booking
  });
}));

/**
 * POST /api/v1/bookings/:id/decline
 * Provider declines a booking request
 */
router.post('/:id/decline', verifyToken, validateBody(reasonSchema), asyncHandler(async (req, res) => {
  const booking = await bookingService.declineBooking(req.user, req.params.id, req.validatedBody.reason);
  res.status(200).json({
    success: true,
    message: 'Booking declined',
    data: booking
  });
}));

/**
 * POST /api/v1/bookings/:id/cancel
 * Cancel a booking
 */
router.post('/:id/cancel', verifyToken, validateBody(reasonSchema), asyncHandler(async (req, res) => {
  const booking = await bookingService.cancelBooking(req.user, req.params.id, req.validatedBody.reason);
  res.status(200).json({
    success: true,
    message: 'Booking cancelled',
    data: booking
  });
}));

router.post('/:id/start', verifyToken, asyncHandler(async (req, res) => {
  const booking = await bookingService.startBooking(req.user, req.params.id);
  res.status(200).json({ success: true, message: 'Booking started', data: booking });
}));

/**
 * POST /api/v1/bookings/:id/complete
 * Mark booking as completed
 */
router.post('/:id/complete', verifyToken, asyncHandler(async (req, res) => {
  const booking = await bookingService.completeBooking(req.user, req.params.id);
  res.status(200).json({
    success: true,
    message: 'Booking marked as completed',
    data: booking
  });
}));

/**
 * GET /api/v1/bookings
 * List user's bookings with filtering
 * Query params: status, page, limit
 */
router.get('/', verifyToken, asyncHandler(async (req, res) => {
  const result = await bookingService.listBookings(req.user, req.query);
  res.status(200).json({
    success: true,
    data: result
  });
}));

export default router;
