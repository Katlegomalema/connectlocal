/**
 * Provider Routes
 * Handles service provider profile and service management
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken, requireRole } from '../middleware/auth.js';
import { validateBody } from '../middleware/validation.js';
import * as providerService from '../services/providerService.js';

const router = express.Router();
const providerUpdateSchema = z.object({
  businessName: z.string().min(2).max(150).optional(),
  category: z.string().min(2).max(50).optional(),
  description: z.string().max(5000).optional(),
  serviceAreaRadiusKm: z.number().int().min(1).max(50).optional()
}).strict();
const serviceSchema = z.object({
  title: z.string().min(2).max(150),
  description: z.string().max(5000).optional(),
  category: z.string().min(2).max(50),
  price: z.coerce.number().min(0).max(1000000),
  durationMinutes: z.coerce.number().int().min(1).max(1440),
  isActive: z.boolean().optional()
}).strict();
const updateServiceSchema = serviceSchema.partial();
const registerProviderSchema = z.object({
  businessName: z.string().min(2).max(150),
  category: z.string().min(2).max(50),
  description: z.string().max(5000).optional(),
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
  serviceAreaRadiusKm: z.coerce.number().int().min(1).max(50).optional()
}).strict();
const verificationSchema = z.object({ documentUrl: z.string().url() }).strict();

router.post('/register', verifyToken, requireRole('provider'), validateBody(registerProviderSchema), asyncHandler(async (req, res) => {
  const provider = await providerService.registerProvider(req.user, req.validatedBody);
  res.status(201).json({ success: true, message: 'Provider profile created', data: { provider } });
}));

router.post('/:id/verification', verifyToken, requireRole('provider', 'admin'), validateBody(verificationSchema), asyncHandler(async (req, res) => {
  const provider = await providerService.submitVerification(req.user, req.params.id, req.validatedBody.documentUrl);
  res.status(200).json({ success: true, message: 'Verification submitted', data: { provider } });
}));

/**
 * GET /api/v1/providers/:id
 * Fetch provider profile
 */
router.get('/:id', asyncHandler(async (req, res) => {
  const provider = await providerService.getPublicProvider(req.params.id);
  res.status(200).json({
    success: true,
    data: { provider }
  });
}));

/**
 * PUT /api/v1/providers/:id
 * Update provider profile
 */
router.put('/:id', verifyToken, requireRole('provider', 'admin'), validateBody(providerUpdateSchema), asyncHandler(async (req, res) => {
  const provider = await providerService.updateProviderProfile(req.user, req.params.id, req.validatedBody);
  res.status(200).json({
    success: true,
    message: 'Profile updated successfully',
    data: { provider }
  });
}));

/**
 * POST /api/v1/providers/:id/services
 * Create a new service listing
 */
router.post('/:id/services', verifyToken, requireRole('provider', 'admin'), validateBody(serviceSchema), asyncHandler(async (req, res) => {
  const service = await providerService.createService(req.user, req.params.id, req.validatedBody);
  res.status(201).json({
    success: true,
    message: 'Service created successfully',
    data: { service }
  });
}));

/**
 * GET /api/v1/providers/:id/services
 * Fetch all services offered by a provider
 */
router.get('/:id/services', asyncHandler(async (req, res) => {
  const services = await providerService.getProviderServices(req.params.id);
  res.status(200).json({
    success: true,
    data: { services }
  });
}));

/**
 * PUT /api/v1/providers/:id/services/:serviceId
 * Update a service listing
 */
router.put('/:id/services/:serviceId', verifyToken, requireRole('provider', 'admin'), validateBody(updateServiceSchema), asyncHandler(async (req, res) => {
  const service = await providerService.updateService(req.user, req.params.id, req.params.serviceId, req.validatedBody);
  res.status(200).json({
    success: true,
    message: 'Service updated successfully',
    data: { service }
  });
}));

/**
 * DELETE /api/v1/providers/:id/services/:serviceId
 * Deactivate a service listing
 */
router.delete('/:id/services/:serviceId', verifyToken, requireRole('provider', 'admin'), asyncHandler(async (req, res) => {
  await providerService.deactivateService(req.user, req.params.id, req.params.serviceId);
  res.status(200).json({
    success: true,
    message: 'Service deactivated successfully'
  });
}));

/**
 * GET /api/v1/providers/:id/availability
 * Fetch provider's availability calendar
 */
router.get('/:id/availability', asyncHandler(async (req, res) => {
  const availability = await providerService.getAvailability(req.params.id);
  res.status(200).json({ success: true, data: { availability } });
}));

/**
 * PUT /api/v1/providers/:id/availability
 * Update provider's availability
 */
router.put('/:id/availability', verifyToken, requireRole('provider', 'admin'), asyncHandler(async (req, res) => {
  const availability = await providerService.updateAvailability(req.user, req.params.id, req.body);
  res.status(200).json({ success: true, message: 'Availability updated successfully', data: { availability } });
}));

export default router;
