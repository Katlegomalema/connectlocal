/**
 * Payment Routes
 * Handles payment processing and transaction management
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken, requireRole } from '../middleware/auth.js';
import { validateBody, validateUuidParam } from '../middleware/validation.js';
import * as paymentService from '../services/paymentService.js';

const router = express.Router();
router.param('id', validateUuidParam);
const intentSchema = z.object({
  bookingId: z.string().uuid(),
  purpose: z.enum(['booking_fee', 'balance']).default('booking_fee')
}).strict();
const confirmSchema = z.object({ paymentId: z.string().min(1) }).strict();

/**
 * POST /api/v1/payments/intent
 * Create a payment intent for a booking
 */
router.post('/intent', verifyToken, validateBody(intentSchema), asyncHandler(async (req, res) => {
  const payment = await paymentService.createPaymentIntent(
    req.user,
    req.validatedBody.bookingId,
    req.validatedBody.purpose
  );
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

/**
 * Where the request really came from: the direct peer, plus the LAST n X-Forwarded-For entries (the ones our
 * own proxy, e.g. the Codespaces port forwarder, appended). Entries further left are written by the caller
 * and can be faked, so they are ignored. n = PAYFAST_TRUSTED_PROXY_HOPS (default 1).
 */
const sourceAddresses = (req) => {
  const hops = Math.max(0, Math.min(5, Number.parseInt(process.env.PAYFAST_TRUSTED_PROXY_HOPS ?? '1', 10) || 0));
  const forwarded = String(req.headers['x-forwarded-for'] || '').split(',').map((ip) => ip.trim()).filter(Boolean);
  return [req.socket.remoteAddress, ...(hops ? forwarded.slice(-hops) : [])];
};

const escapeHtml = (value) => String(value)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;');

const page = (res, status, title, body) => {
  res.set('Cache-Control', 'no-store');
  res.set('Referrer-Policy', 'no-referrer');
  res.status(status).type('html').send(`<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>${escapeHtml(title)}</title>
<style>body{font-family:system-ui,sans-serif;max-width:420px;margin:15vh auto;padding:0 20px;text-align:center;color:#1f2a44}
h1{font-size:1.3rem}button{background:#0f8b8d;color:#fff;border:0;border-radius:10px;padding:12px 20px;font-size:1rem}</style>
</head><body>${body}</body></html>`);
};

/**
 * GET /api/v1/payments/:id/checkout?e=&t=   (opened by the app in a browser; the signed link is the permission)
 * Posts the signed form to PayFast automatically.
 */
router.get('/:id/checkout', asyncHandler(async (req, res) => {
  let checkout;
  try {
    checkout = await paymentService.getCheckoutForm(req.params.id, req.query.e, req.query.t);
  } catch (error) {
    return page(res, error.statusCode || 400, 'Payment link', `<h1>Payment link not available</h1><p>${escapeHtml(error.message)}</p>`);
  }
  const inputs = Object.entries(checkout.payload)
    .map(([name, value]) => `<input type="hidden" name="${escapeHtml(name)}" value="${escapeHtml(value)}">`)
    .join('');
  return page(res, 200, 'Opening PayFast…', `<h1>Opening PayFast…</h1><p>You will pay R${escapeHtml(checkout.payload.amount)} securely on PayFast.</p>
<form id="pf" method="post" action="${escapeHtml(checkout.url)}">${inputs}<button type="submit">Continue to PayFast</button></form>
<script>document.getElementById('pf').submit();</script>`);
}));

router.get('/return', (req, res) => page(
  res,
  200,
  'Payment received',
  '<h1>Thank you!</h1><p>PayFast is confirming your payment. Go back to the ConnectLocal app; it updates by itself in a few seconds.</p>'
));

router.get('/cancel', (req, res) => page(
  res,
  200,
  'Payment cancelled',
  '<h1>Payment cancelled</h1><p>Nothing was charged. Go back to the ConnectLocal app to try again.</p>'
));

router.post('/payfast/itn', asyncHandler(async (req, res) => {
  try {
    await paymentService.processPayFastItn(req.body, sourceAddresses(req));
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
    await paymentService.processPayFastItn(req.body, sourceAddresses(req));
  } catch (error) {
    req.log?.error({ err: error }, 'PayFast webhook processing failed');
  }
  res.status(200).type('text/plain').send('OK');
}));

export default router;
