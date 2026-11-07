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
import {
  BUSINESS_NAME, PERSON_NAME, bankAccountSchema, branchCodeSchema, businessNameSchema, lineSchema, priceSchema,
  registrationNumberSchema, textSchema
} from '../utils/validators.js';
import * as payoutService from '../services/payoutService.js';
import * as scheduleService from '../services/scheduleService.js';
import * as searchService from '../services/searchService.js';

const router = express.Router();
router.param('serviceId', validateUuidParam);
router.param('packageId', validateUuidParam);
const locationSchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180)
}).strict();
const placeSchema = (max, label) => lineSchema(max, { label });
const postalCodeSchema = z.string().trim().regex(/^\d{4}$/, 'Postal codes have 4 digits');
const holderNameSchema = lineSchema(150, { min: 2, label: 'The account holder' })
  .refine((v) => PERSON_NAME.test(v) || BUSINESS_NAME.test(v), 'Use the name on the bank account (letters, spaces, - and \')');
const providerUpdateSchema = z.object({
  businessName: businessNameSchema.optional(),
  registrationNumber: registrationNumberSchema.optional(),
  category: lineSchema(100, { min: 2, label: 'The category' }).optional(),
  categoryId: z.string().uuid().optional(),
  description: textSchema(5000, { label: 'The description' }).optional(),
  streetAddress: lineSchema(150, { min: 5, label: 'The address' }).optional(),
  suburb: placeSchema(100, 'The suburb').optional(),
  city: placeSchema(100, 'The city').optional(),
  province: placeSchema(100, 'The province').optional(),
  postalCode: postalCodeSchema.optional(),
  location: locationSchema.optional(),
  serviceAreaRadiusKm: z.coerce.number().int().min(1).max(50)
    .optional()
}).strict();
const serviceSchema = z.object({
  title: lineSchema(100, { min: 2, label: 'The service name' }),
  description: textSchema(5000, { label: 'The description' }).optional(),
  category: lineSchema(100, { min: 2, label: 'The category' }),
  price: priceSchema,
  durationMinutes: z.coerce.number().int().min(1).max(1440),
  pricingType: z.enum(['hourly', 'fixed', 'package']).optional(),
  isActive: z.boolean().optional()
}).strict();
const updateServiceSchema = serviceSchema.partial();
const packageSchema = z.object({
  name: lineSchema(100, { min: 2, label: 'The package name' }),
  description: textSchema(1000, { label: 'The package description' }).nullable().optional(),
  price: priceSchema,
  durationMinutes: z.coerce.number().int().min(1).max(1440)
    .optional(),
  sortOrder: z.number().int().optional(),
  isActive: z.boolean().optional()
}).strict();
const updatePackageSchema = packageSchema.partial();
const registerProviderSchema = z.object({
  businessName: businessNameSchema,
  registrationNumber: registrationNumberSchema,
  category: lineSchema(100, { min: 2, label: 'The category' }).optional(),
  categoryId: z.string().uuid().optional(),
  description: textSchema(5000, { label: 'The description' }).optional(),
  streetAddress: lineSchema(150, { min: 5, label: 'The address' }).optional(),
  suburb: placeSchema(100, 'The suburb').optional(),
  city: placeSchema(100, 'The city').optional(),
  province: placeSchema(100, 'The province').optional(),
  postalCode: postalCodeSchema.optional(),
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
  caption: textSchema(200, { label: 'The caption' }).optional()
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
  res.status(200).json({
    success: true,
    data: { provider: { ...provider, location: providerService.publicLocation(provider.location) } }
  });
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

// ---- payouts: bank details (account number encrypted, only last 4 digits returned) + payout history ----
const payoutDetailsSchema = z.object({
  bankName: lineSchema(100, { min: 2, label: 'The bank' }),
  accountType: z.enum(['Cheque / Current', 'Savings', 'Transmission']),
  accountHolderName: holderNameSchema,
  accountNumber: bankAccountSchema,
  branchCode: branchCodeSchema
}).strict();

router.get('/me/payout-details', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, data: { payoutDetails: await payoutService.getPayoutDetails(req.user) } });
}));

router.put('/me/payout-details', verifyToken, requireRole('provider'), validateBody(payoutDetailsSchema), asyncHandler(async (req, res) => {
  const payoutDetails = await payoutService.savePayoutDetails(req.user, req.validatedBody);
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, message: 'Bank details saved', data: { payoutDetails } });
}));

router.get('/me/payouts', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  res.status(200).json({ success: true, data: { payouts: await payoutService.listMyPayouts(req.user) } });
}));

const scheduleSchema = z.object({
  offersVisit: z.boolean().optional(),
  offersHouseCall: z.boolean().optional(),
  slotMinutes: z.number().int().optional(),
  workingHours: z.array(z.object({
    day: z.number().int().min(1).max(7),
    open: z.number().int().min(0).max(1440),
    close: z.number().int().min(0).max(1440)
  }).strict()).max(7).optional()
}).strict();

/** GET/PUT /providers/me/schedule: visit / house call, slot length and working hours. */
router.get('/me/schedule', verifyToken, requireRole('provider'), asyncHandler(async (req, res) => {
  res.status(200).json({ success: true, data: { schedule: await scheduleService.getOwnSchedule(req.user) } });
}));

router.put('/me/schedule', verifyToken, requireRole('provider'), validateBody(scheduleSchema), asyncHandler(async (req, res) => {
  const schedule = await scheduleService.saveOwnSchedule(req.user, req.validatedBody);
  res.status(200).json({ success: true, message: 'Booking options saved', data: { schedule } });
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
/** GET /providers/:id/schedule (public): booking options, working hours and the times already taken. */
router.get('/:id/schedule', asyncHandler(async (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, data: await scheduleService.getPublicSchedule(req.params.id) });
}));

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
