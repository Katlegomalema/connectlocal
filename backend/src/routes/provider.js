/**
 * Provider Routes
 * Handles service provider profile and service management
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken, requireRole, optionalToken } from '../middleware/auth.js';
import { validateBody, validateUuidParam } from '../middleware/validation.js';
import * as providerService from '../services/providerService.js';
import * as searchService from '../services/searchService.js';

const router = express.Router();
router.param('serviceId', validateUuidParam);
router.param('packageId', validateUuidParam);
const locationSchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180)
}).strict();
const registrationNumberSchema = z.string().trim()
  .regex(/^\d{4}\/\d{6}\/\d{2}$/, 'Registration number must look like 2019/123456/07 (YYYY/NNNNNN/TT)');
const providerUpdateSchema = z.object({
  businessName: z.string().min(2).max(150).optional(),
  registrationNumber: registrationNumberSchema.optional(),
  category: z.string().min(2).max(50).optional(),
  categoryId: z.string().uuid().optional(),
  description: z.string().max(5000).optional(),
  streetAddress: z.string().max(150).optional(),
  suburb: z.string().max(100).optional(),
  city: z.string().max(100).optional(),
  province: z.string().max(100).optional(),
  postalCode: z.string().max(20).optional(),
  location: locationSchema.optional(),
  serviceAreaRadiusKm: z.coerce.number().int().min(1).max(50)
    .optional()
}).strict();
const serviceSchema = z.object({
  title: z.string().min(2).max(150),
  description: z.string().max(5000).optional(),
  category: z.string().min(2).max(50),
  price: z.coerce.number().min(0).max(1000000),
  durationMinutes: z.coerce.number().int().min(1).max(1440),
  pricingType: z.enum(['hourly', 'fixed', 'package']).optional(),
  isActive: z.boolean().optional()
}).strict();
const updateServiceSchema = serviceSchema.partial();
const packageSchema = z.object({
  name: z.string().min(2).max(100),
  description: z.string().max(2000).nullable().optional(),
  price: z.coerce.number().positive().max(1000000),
  durationMinutes: z.coerce.number().int().min(1).max(1440)
    .optional(),
  sortOrder: z.number().int().optional(),
  isActive: z.boolean().optional()
}).strict();
const updatePackageSchema = packageSchema.partial();
const registerProviderSchema = z.object({
  businessName: z.string().min(2).max(150),
  registrationNumber: registrationNumberSchema,
  category: z.string().min(2).max(50).optional(),
  categoryId: z.string().uuid().optional(),
  description: z.string().max(5000).optional(),
  streetAddress: z.string().max(150).optional(),
  suburb: z.string().max(100).optional(),
  city: z.string().max(100).optional(),
  province: z.string().max(100).optional(),
  postalCode: z.string().max(20).optional(),
  location: locationSchema.optional(),
  latitude: z.coerce.number().min(-90).max(90).optional(),
  longitude: z.coerce.number().min(-180).max(180).optional(),
  serviceAreaRadiusKm: z.coerce.number().int().min(1).max(50)
    .optional()
}).strict().refine((value) => value.category || value.categoryId, {
  message: 'category or categoryId is required',
  path: ['category']
}).refine((value) => (value.latitude === undefined) === (value.longitude === undefined), {
  message: 'Send both latitude and longitude, or neither',
  path: ['location']
});
const documentSchema = z.object({
  documentType: z.enum(['registration_certificate', 'id_document', 'proof_of_address', 'other']),
  storagePath: z.string().min(10).max(300) // from POST /uploads/sign (purpose provider_document)
}).strict();
const photoSchema = z.object({
  storagePath: z.string().min(10).max(300), // from POST /uploads/sign (purpose provider_photo)
  caption: z.string().max(200).optional()
}).strict();

const registerProviderHandler = asyncHandler(async (req, res) => {
  const provider = await providerService.registerProvider(req.user, req.validatedBody);
  res.status(201).json({ success: true, message: 'Provider profile created', data: { provider } });
});

router.post('/', verifyToken, requireRole('provider'), validateBody(registerProviderSchema), registerProviderHandler);
router.post('/register', verifyToken, requireRole('provider'), validateBody(registerProviderSchema), registerProviderHandler);

router.param('photoId', validateUuidParam);
router.param('imageId', validateUuidParam);

/**
 * Provider application ("Become a provider"):
 *   GET  /me/application          status (draft/submitted/approved/rejected), what is missing, documents, photos
 *   POST /me/documents            { documentType, storagePath }  (also: POST /me/verification)
 *   POST /me/application/submit   send it to the admin
 *   POST /me/photos               { storagePath, caption? }   DELETE /me/photos/:photoId
 */
router.get('/me/application', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  const application = await providerService.getOwnApplication(req.user);
  res.status(200).json({ success: true, data: { application } });
}));

const attachDocumentHandler = asyncHandler(async (req, res) => {
  const provider = await providerService.getOwnProvider(req.user);
  const document = await providerService.attachDocument(req.user, provider.id, req.validatedBody);
  res.status(201).json({ success: true, data: { document } });
});
router.post('/me/documents', verifyToken, requireRole('provider'), validateBody(documentSchema), attachDocumentHandler);
router.post('/me/verification', verifyToken, requireRole('provider'), validateBody(documentSchema), attachDocumentHandler);

router.post('/me/application/submit', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  const application = await providerService.submitApplication(req.user);
  res.status(200).json({ success: true, message: 'Application sent for review', data: { application } });
}));

router.post('/me/photos', verifyToken, requireRole('provider'), validateBody(photoSchema), asyncHandler(async (req, res) => {
  const photo = await providerService.addProviderPhoto(req.user, req.validatedBody);
  res.status(201).json({ success: true, data: { photo } });
}));

router.delete('/me/photos/:photoId', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  const result = await providerService.removeProviderPhoto(req.user, req.params.photoId);
  res.status(200).json({ success: true, data: result });
}));

router.get('/search', optionalToken, asyncHandler(async (req, res) => {
  if (req.query.lat !== undefined || req.query.lng !== undefined) {
    const result = await searchService.searchNearby(
      req.query.lat,
      req.query.lng,
      req.query.radiusKm,
      {
        category: req.query.category,
        minRating: req.query.minRating,
        maxPrice: req.query.maxPrice
      }
    );
    return res.status(200).json({ success: true, data: result });
  }

  const result = await searchService.searchProviders(
    req.query.q,
    req.query.category,
    req.query.page,
    req.query.pageSize
  );
  return res.status(200).json({ success: true, data: result });
}));

router.get('/me', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  const provider = await providerService.getOwnProvider(req.user);
  res.status(200).json({ success: true, data: { provider } });
}));

router.patch('/me', verifyToken, requireRole('provider'), validateBody(providerUpdateSchema), asyncHandler(async (req, res) => {
  const provider = await providerService.getOwnProvider(req.user);
  const updated = await providerService.updateProviderProfile(req.user, provider.id, req.validatedBody);
  res.status(200).json({ success: true, message: 'Profile updated successfully', data: { provider: updated } });
}));

router.post('/me/services', verifyToken, requireRole('provider'), validateBody(serviceSchema), asyncHandler(async (req, res) => {
  const provider = await providerService.getOwnProvider(req.user);
  const service = await providerService.createService(req.user, provider.id, req.validatedBody);
  res.status(201).json({ success: true, data: { service } });
}));

router.post('/me/services/:serviceId/packages', verifyToken, requireRole('provider'), validateBody(packageSchema), asyncHandler(async (req, res) => {
  const provider = await providerService.getOwnProvider(req.user);
  const pkg = await providerService.createPackage(req.user, provider.id, req.params.serviceId, req.validatedBody);
  res.status(201).json({ success: true, data: { package: pkg } });
}));

router.patch('/me/services/:serviceId/packages/:packageId', verifyToken, requireRole('provider'), validateBody(updatePackageSchema), asyncHandler(async (req, res) => {
  const provider = await providerService.getOwnProvider(req.user);
  const pkg = await providerService.updatePackage(
    req.user,
    provider.id,
    req.params.serviceId,
    req.params.packageId,
    req.validatedBody
  );
  res.status(200).json({ success: true, data: { package: pkg } });
}));

router.delete('/me/services/:serviceId/packages/:packageId', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  const provider = await providerService.getOwnProvider(req.user);
  const pkg = await providerService.deactivatePackage(
    req.user,
    provider.id,
    req.params.serviceId,
    req.params.packageId
  );
  res.status(200).json({ success: true, message: 'Package deactivated', data: { package: pkg } });
}));

router.get('/me/services', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  const services = await providerService.getOwnServices(req.user);
  res.status(200).json({ success: true, data: { services } });
}));

router.patch('/me/services/:serviceId', verifyToken, requireRole('provider'), validateBody(updateServiceSchema), asyncHandler(async (req, res) => {
  const provider = await providerService.getOwnProvider(req.user);
  const service = await providerService.updateService(req.user, provider.id, req.params.serviceId, req.validatedBody);
  res.status(200).json({ success: true, data: { service } });
}));

router.delete('/me/services/:serviceId', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  const provider = await providerService.getOwnProvider(req.user);
  const service = await providerService.deactivateService(req.user, provider.id, req.params.serviceId);
  res.status(200).json({ success: true, message: 'Service deactivated', data: { service } });
}));

router.post('/me/services/:serviceId/photos', verifyToken, requireRole('provider'), validateBody(photoSchema), asyncHandler(async (req, res) => {
  const photo = await providerService.addServicePhoto(req.user, req.params.serviceId, req.validatedBody.storagePath);
  res.status(201).json({ success: true, data: { photo } });
}));

router.delete('/me/services/:serviceId/photos/:imageId', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  const result = await providerService.removeServicePhoto(req.user, req.params.serviceId, req.params.imageId);
  res.status(200).json({ success: true, data: result });
}));

router.get('/me/availability', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  const provider = await providerService.getOwnProvider(req.user);
  const availability = await providerService.getAvailability(provider.id);
  res.status(200).json({ success: true, data: { availability } });
}));

router.put('/me/availability', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  const provider = await providerService.getOwnProvider(req.user);
  const availability = await providerService.updateAvailability(req.user, provider.id, req.body);
  res.status(200).json({ success: true, message: 'Availability updated successfully', data: { availability } });
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
