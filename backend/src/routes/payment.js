/**
 * Payment Routes
 * Handles payment processing and transaction management
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken, requireRole } from '../middleware/auth.js';
import { validateBody } from '../middleware/validation.js';
import * as paymentService from '../services/paymentService.js';

const router = express.Router();
const intentSchema = z.object({ bookingId: z.string().min(1) }).strict();
const confirmSchema = z.object({ paymentId: z.string().min(1) }).strict();

/**
 * POST /api/v1/payments/intent
 * Create a payment intent for a booking
 */
router.post('/intent', verifyToken, validateBody(intentSchema), asyncHandler(async (req, res) => {
  const payment = await paymentService.createPaymentIntent(req.user, req.validatedBody.bookingId);
  res.status(201).json({
    success: true,
    message: 'Payment intent created',
    data: payment
  });
}));

/**
 * POST /api/v1/payments/confirm
 * Confirm payment after payment gateway returns
 */
router.post('/confirm', verifyToken, validateBody(confirmSchema), asyncHandler(async (req, res) => {
  const payment = await paymentService.confirmPayment(req.user, req.validatedBody.paymentId);
  res.status(200).json({
    success: true,
    message: 'Payment status retrieved; only a verified PayFast ITN can confirm payment',
    data: payment
  });
}));

router.post('/payfast/itn', asyncHandler(async (req, res) => {
  try {
    await paymentService.processPayFastItn(req.body, req.socket.remoteAddress);
  } catch (error) {
    req.log?.error({ err: error }, 'PayFast ITN processing failed');
  }
  res.status(200).type('text/plain').send('OK');
}));

/**
 * GET /api/v1/payments/:id
 * Fetch payment details
 */
router.get('/:id', verifyToken, asyncHandler(async (req, res) => {
  const payment = await paymentService.getPayment(req.user, req.params.id);
  res.status(200).json({
    success: true,
    data: payment
  });
}));

router.get('/:id/receipt', verifyToken, asyncHandler(async (req, res) => {
  const receipt = await paymentService.getReceipt(req.user, req.params.id);
  res.status(200).json({ success: true, data: receipt });
}));

/**
 * GET /api/v1/payments
 * List user's payment history
 * Query params: page, limit, status
 */
router.get('/', verifyToken, asyncHandler(async (req, res) => {
  const result = await paymentService.listPayments(req.user, req.query);
  res.status(200).json({
    success: true,
    data: result
  });
}));

/**
 * POST /api/v1/payments/:id/refund
 * Initiate a refund for a payment
 */
router.post('/:id/refund', verifyToken, requireRole('admin'), asyncHandler(async (req, res) => {
  const payment = await paymentService.processRefund(req.user, req.params.id);
  res.status(200).json({
    success: true,
    message: 'Refund processed',
    data: payment
  });
}));

/**
 * POST /api/v1/payments/webhook
 * Handle payment gateway webhooks
 */
router.post('/webhook', asyncHandler(async (req, res) => {
  try {
    await paymentService.processPayFastItn(req.body, req.socket.remoteAddress);
  } catch (error) {
    req.log?.error({ err: error }, 'PayFast webhook processing failed');
  }
  res.status(200).type('text/plain').send('OK');
}));

export default router;
