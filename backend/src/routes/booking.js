/**
 * Booking Routes
 * Handles booking creation, management, and status updates
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken } from '../middleware/auth.js';
import { validateBody, validateUuidParam } from '../middleware/validation.js';
import * as bookingService from '../services/bookingService.js';
import { addressSchema, pinSchema, textSchema } from '../utils/validators.js';

const router = express.Router();
const createBookingSchema = z.object({
  providerId: z.string().uuid(),
  serviceId: z.string().uuid(),
  scheduledStart: z.string().min(1),
  packageId: z.string().uuid().optional(), // for package-priced services
  hours: z.number().int().min(1).max(24)
    .optional(), // for hourly services
  // true = the customer visits the business; false (default) = house call at [address]
  atBusiness: z.boolean().optional(),
  address: addressSchema.optional(), // where the job happens (house call)
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  notes: textSchema(1000, { label: 'Notes' }).optional()
}).strict().refine((body) => (body.latitude === undefined) === (body.longitude === undefined), {
  message: 'Send both latitude and longitude, or neither',
  path: ['latitude']
}).refine((body) => body.atBusiness === true || Boolean(body.address), {
  message: 'Enter the address where the provider should come',
  path: ['address']
});
const startSchema = z.object({ pin: pinSchema }).strict();

router.param('id', validateUuidParam);
const rescheduleSchema = z.object({ scheduledStart: z.string().min(1) });
const reasonSchema = z.object({ reason: textSchema(1000, { label: 'The reason' }).optional() });
const respondSchema = z.discriminatedUnion('action', [
  z.object({ action: z.literal('accept') }).strict(),
  z.object({ action: z.literal('decline'), reason: textSchema(1000, { label: 'The reason' }).optional() }).strict()
]);
const rescheduleRequestSchema = z.object({
  scheduledStart: z.string().min(1).optional(),
  newScheduledStart: z.string().min(1).optional()
}).strict().refine((value) => Boolean(value.scheduledStart || value.newScheduledStart), {
  message: 'scheduledStart is required',
  path: ['scheduledStart']
});

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

router.patch('/:id/reschedule', verifyToken, validateBody(rescheduleRequestSchema), asyncHandler(async (req, res) => {
  const booking = await bookingService.rescheduleBooking(
    req.user,
    req.params.id,
    req.validatedBody.newScheduledStart || req.validatedBody.scheduledStart
  );
  res.status(200).json({ success: true, message: 'Booking rescheduled successfully', data: booking });
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

router.patch('/:id/respond', verifyToken, validateBody(respondSchema), asyncHandler(async (req, res) => {
  const booking = req.validatedBody.action === 'accept'
    ? await bookingService.acceptBooking(req.user, req.params.id)
    : await bookingService.declineBooking(req.user, req.params.id, req.validatedBody.reason);
  res.status(200).json({ success: true, data: booking });
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

router.patch('/:id/cancel', verifyToken, validateBody(reasonSchema), asyncHandler(async (req, res) => {
  const booking = await bookingService.cancelBooking(req.user, req.params.id, req.validatedBody.reason);
  res.status(200).json({ success: true, data: booking });
}));

/**
 * GET /api/v1/bookings/:id/arrival-pin
 * Customer only: the 4-digit PIN to give the provider on arrival.
 */
router.get('/:id/arrival-pin', verifyToken, asyncHandler(async (req, res) => {
  const pin = await bookingService.getArrivalPin(req.user, req.params.id);
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, data: pin });
}));

/**
 * POST /api/v1/bookings/:id/start   body: { pin: "1234" }
 * Provider enters the customer's PIN on arrival; the job starts.
 */
router.post('/:id/start', verifyToken, validateBody(startSchema), asyncHandler(async (req, res) => {
  const booking = await bookingService.startBooking(req.user, req.params.id, req.validatedBody.pin);
  res.status(200).json({ success: true, message: 'Booking started', data: booking });
}));

/**
 * POST /api/v1/bookings/:id/balance/cash-choice
 * Customer chooses to pay the balance in cash (the provider confirms it later).
 */
router.post('/:id/balance/cash-choice', verifyToken, asyncHandler(async (req, res) => {
  const booking = await bookingService.chooseCashBalance(req.user, req.params.id);
  res.status(200).json({ success: true, message: 'Cash payment chosen', data: booking });
}));

/**
 * POST /api/v1/bookings/:id/balance/cash
 * Provider confirms the customer paid the balance in cash.
 */
router.post('/:id/balance/cash', verifyToken, asyncHandler(async (req, res) => {
  const result = await bookingService.confirmCashBalance(req.user, req.params.id);
  res.status(200).json({ success: true, message: 'Cash payment recorded', data: result });
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
