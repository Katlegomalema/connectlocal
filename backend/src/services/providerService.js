/**
 * Provider Service
 * Provider profiles and service catalogue operations
 */

import * as providerRepository from '../repositories/providerRepository.js';
import * as notificationService from './notificationService.js';
import * as storage from '../integrations/storage.js';
import logger from '../utils/logger.js';
import { toLatLng } from '../utils/geo.js';
import { BUSINESS_NAME, checkRegistrationNumber } from '../utils/validators.js';
import {
  AuthorizationError, ConflictError, NotFoundError, ValidationError
} from '../utils/errors.js';

const providerProfileFields = [
  'id', 'business_name', 'business_description', 'street_address', 'suburb',
  'city', 'province', 'postal_code', 'service_radius_km',
  'primary_category_id', 'location', 'verification_status', 'rating_average', 'rating_count'
];

/** CIPC company registration number, e.g. 2019/123456/07 (also enforced by the database). */
export const REGISTRATION_NUMBER = /^\d{4}\/\d{6}\/\d{2}$/;
export const DOCUMENT_TYPES = ['registration_certificate', 'id_document', 'proof_of_address', 'other'];
/** Needed before an application can be sent to the admin. */
export const REQUIRED_DOCUMENTS = ['registration_certificate', 'id_document'];

/** Notifications are a nice-to-have: never let a failed push undo the real action. */
const notifySafely = async (userId, notification) => {
  try {
    await notificationService.sendInAppNotification(userId, notification);
  } catch (error) {
    logger.warn({ err: error, userId }, 'Notification could not be sent');
  }
};

const normaliseRegistrationNumber = (value) => {
  const number = typeof value === 'string' ? value.trim() : '';
  // Same rule as the app and the route schema (utils/validators.js): format, year and company type.
  const problem = checkRegistrationNumber(number);
  if (problem) throw new ValidationError(problem);
  return number;
};

const assertRegistrationNumberFree = async (registrationNumber, exceptProviderId = null) => {
  if (await providerRepository.registrationNumberInUse(registrationNumber, exceptProviderId)) {
    throw new ConflictError('A business with this registration number has already applied');
  }
};

const assertBusinessName = (name) => {
  if (!name || name.length < 2 || name.length > 150 || !BUSINESS_NAME.test(name)) {
    throw new ValidationError('Please enter a valid business name (letters, digits, spaces and & . , \' ( ) - only)');
  }
};

const isUuid = (value) => typeof value === 'string' && /^[0-9a-f-]{36}$/i.test(value);

const resolveCategoryId = async (value) => {
  if (!value) return null;
  const category = isUuid(value)
    ? await providerRepository.getServiceCategoryById(value)
    : await providerRepository.getServiceCategoryByName(value.trim());
  return category.id;
};

const locationValue = (location) => {
  const latitude = Number(location?.lat ?? location?.latitude);
  const longitude = Number(location?.lng ?? location?.longitude);
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90
      || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new ValidationError('location must contain valid latitude and longitude coordinates');
  }
  return `SRID=4326;POINT(${longitude} ${latitude})`;
};

/** { latitude, longitude } or null, whatever format PostGIS/PostgREST returned. */
export const publicLocation = (location) => toLatLng(location);

const assertProviderOwner = (actor, provider) => {
  if (actor.role !== 'admin' && (actor.role !== 'provider' || provider.user_id !== actor.id)) {
    throw new AuthorizationError('You do not manage this provider profile');
  }
};

export const getOwnProvider = async (actor) => {
  if (actor?.role !== 'provider') throw new AuthorizationError('Only provider accounts have provider profiles');
  const provider = await providerRepository.getProviderByUserId(actor.id);
  if (!provider) throw new NotFoundError('Provider profile not found');
  return provider;
};

const validateService = (input, partial = false) => {
  const service = {};
  const fields = [
    'name', 'title', 'description', 'categoryId', 'category',
    'price', 'currency', 'durationMinutes', 'minNoticeHours', 'active', 'isActive', 'pricingType'
  ];
  const name = input.name ?? input.title;
  const category = input.categoryId ?? input.category;
  if (!partial && (!name || !category || input.price === undefined || input.durationMinutes === undefined)) {
    throw new ValidationError('title, category, price, and durationMinutes are required');
  }
  if (name !== undefined) {
    if (typeof name !== 'string' || name.trim().length < 2 || name.trim().length > 150) throw new ValidationError('title must contain 2 to 150 characters');
    service.service_name = name.trim();
  }
  if (input.description !== undefined) {
    if (typeof input.description !== 'string' || input.description.length > 5000) throw new ValidationError('description cannot exceed 5000 characters');
    service.description = input.description.trim() || null;
  }
  if (category !== undefined) {
    if (typeof category !== 'string' || category.trim().length < 2 || category.trim().length > 100) {
      throw new ValidationError('category must be a category name or UUID');
    }
    service.category_id = category.trim();
  }
  if (input.price !== undefined) {
    const price = Number(input.price);
    if (!Number.isFinite(price) || price < 0 || price > 1000000) throw new ValidationError('price must be between 0 and 1000000');
    service.base_price = Math.round(price * 100) / 100;
  }
  if (input.currency !== undefined) {
    if (typeof input.currency !== 'string' || !/^[A-Z]{3}$/.test(input.currency)) throw new ValidationError('currency must be a 3-letter code');
    service.currency = input.currency;
  }
  if (input.durationMinutes !== undefined) {
    const duration = Number(input.durationMinutes);
    if (!Number.isInteger(duration) || duration < 1 || duration > 1440) throw new ValidationError('durationMinutes must be between 1 and 1440');
    service.duration_minutes = duration;
  }
  if (input.minNoticeHours !== undefined) {
    const hours = Number(input.minNoticeHours);
    if (!Number.isInteger(hours) || hours < 0 || hours > 8760) throw new ValidationError('minNoticeHours must be between 0 and 8760');
    service.min_notice_hours = hours;
  }
  if (input.pricingType !== undefined) {
    if (!['hourly', 'fixed', 'package'].includes(input.pricingType)) {
      throw new ValidationError('pricingType must be hourly, fixed or package');
    }
    service.pricing_type = input.pricingType;
  }
  const active = input.active ?? input.isActive;
  if (active !== undefined) {
    if (typeof active !== 'boolean') throw new ValidationError('isActive must be a boolean');
    service.active = active;
  }
  const unknownFields = Object.keys(input).filter((key) => !fields.includes(key));
  if (unknownFields.length) throw new ValidationError(`Unsupported service fields: ${unknownFields.join(', ')}`);
  return service;
};

export const getPublicProvider = async (providerId) => {
  const provider = await providerRepository.getProviderById(providerId);
  if (provider.verification_status !== 'verified' || !provider.is_active) throw new NotFoundError('Provider not found');
  const profile = Object.fromEntries(providerProfileFields.map((field) => [field, provider[field] ?? null]));
  profile.location = publicLocation(profile.location);
  profile.services = await providerRepository.getProviderServices(providerId);
  return profile;
};

export const registerProvider = async (actor, input) => {
  if (actor?.role !== 'provider') throw new AuthorizationError('Only provider accounts can create provider profiles');
  const existing = await providerRepository.getProviderByUserId(actor.id);
  if (existing) throw new ConflictError('A provider profile already exists for this account');
  const businessName = input.businessName?.trim();
  const radius = input.serviceAreaRadiusKm ?? input.serviceRadiusKm ?? 10;

  assertBusinessName(businessName);
  for (const [field, limit] of [['streetAddress', 150], ['suburb', 100], ['city', 100], ['province', 100], ['postalCode', 20]]) {
    if (input[field] != null && (typeof input[field] !== 'string' || input[field].trim().length > limit)) {
      throw new ValidationError(`${field} must be a string of at most ${limit} characters`);
    }
  }
  if (!Number.isInteger(radius) || radius < 1 || radius > 50) {
    throw new ValidationError('serviceAreaRadiusKm must be between 1 and 50');
  }
  if (input.description != null && (typeof input.description !== 'string' || input.description.length > 5000)) {
    throw new ValidationError('description cannot exceed 5000 characters');
  }
  const categoryId = await resolveCategoryId(input.categoryId ?? input.category);
  if (!categoryId) throw new ValidationError('category or categoryId is required');
  const registrationNumber = normaliseRegistrationNumber(input.registrationNumber);
  await assertRegistrationNumberFree(registrationNumber);
  const hasLocation = input.location || (input.latitude !== undefined && input.longitude !== undefined);

  return providerRepository.createProvider({
    business_registration_number: registrationNumber,
    user_id: actor.id,
    business_name: businessName,
    business_description: input.description?.trim() || null,
    street_address: input.streetAddress?.trim() || null,
    suburb: input.suburb?.trim() || null,
    city: input.city?.trim() || null,
    province: input.province?.trim() || null,
    postal_code: input.postalCode?.trim() || null,
    service_radius_km: radius,
    primary_category_id: categoryId,
    // Optional: without coordinates the business is found by text search only (not "near me").
    location: hasLocation
      ? locationValue(input.location || { latitude: input.latitude, longitude: input.longitude })
      : null,
    verification_status: 'pending',
    rating_average: 0,
    rating_count: 0,
    is_active: true
  });
};

/** Never send storage paths to the app; the admin gets signed links instead. */
const publicDocument = (document) => ({
  id: document.id,
  documentType: document.document_type,
  status: document.approval_status,
  rejectionReason: document.rejection_reason ?? null,
  uploadedAt: document.uploaded_at
});

/**
 * Attach an uploaded document (from POST /uploads/sign, purpose provider_document) to the application.
 */
export const attachDocument = async (actor, providerId, { documentType, storagePath }) => {
  const provider = await providerRepository.getProviderById(providerId);
  assertProviderOwner(actor, provider);
  if (!DOCUMENT_TYPES.includes(documentType)) {
    throw new ValidationError(`documentType must be one of: ${DOCUMENT_TYPES.join(', ')}`);
  }
  if (provider.verification_status === 'verified') {
    throw new ConflictError('Your business is already verified; contact support to change documents');
  }
  await storage.assertOwnUploadedFile(storage.BUCKETS.documents, provider.user_id, 'documents', storagePath);

  const { document, replacedPath } = await providerRepository.saveProviderDocument(
    provider.id,
    documentType,
    storagePath
  );
  if (replacedPath && replacedPath !== storagePath) {
    await storage.removeFiles(storage.BUCKETS.documents, [replacedPath]);
  }
  return publicDocument(document);
};

const applicationState = (provider) => {
  if (provider.verification_status === 'verified') return 'approved';
  if (provider.verification_status === 'rejected') return 'rejected';
  if (provider.verification_status === 'suspended') return 'suspended';
  return provider.submitted_at ? 'submitted' : 'draft';
};

/** The provider's own view of their application (status, missing pieces, documents, photos). */
export const getOwnApplication = async (actor) => {
  const provider = await getOwnProvider(actor);
  const [documents, gallery] = await Promise.all([
    providerRepository.listProviderDocuments(provider.id),
    providerRepository.listGallery(provider.id)
  ]);
  const present = new Set(documents.map((document) => document.document_type));
  const missing = [
    ...(provider.business_registration_number ? [] : ['registration_number']),
    ...REQUIRED_DOCUMENTS.filter((type) => !present.has(type))
  ];
  return {
    id: provider.id,
    businessName: provider.business_name,
    description: provider.business_description ?? null,
    registrationNumber: provider.business_registration_number ?? null,
    city: provider.city ?? null,
    province: provider.province ?? null,
    location: publicLocation(provider.location),
    primaryCategoryId: provider.primary_category_id ?? null,
    status: applicationState(provider),
    verificationStatus: provider.verification_status,
    rejectionReason: provider.rejection_reason ?? null,
    submittedAt: provider.submitted_at ?? null,
    reviewedAt: provider.reviewed_at ?? null,
    missing,
    documents: documents.map(publicDocument),
    photos: gallery.map((photo) => ({ id: photo.id, url: photo.image_url, caption: photo.caption }))
  };
};

/**
 * Send the application to the admin. Needs the registration number and the required documents.
 * After a rejection the provider can fix things and submit again.
 */
export const submitApplication = async (actor) => {
  const provider = await getOwnProvider(actor);
  if (provider.verification_status === 'verified') throw new ConflictError('Your business is already verified');
  if (provider.verification_status === 'suspended') {
    throw new ConflictError('This business is suspended; contact support');
  }
  if (provider.verification_status === 'pending' && provider.submitted_at) {
    throw new ConflictError('Your application is already waiting for review');
  }

  const application = await getOwnApplication(actor);
  if (application.missing.length) {
    const labels = {
      registration_number: 'registration number',
      registration_certificate: 'registration certificate',
      id_document: 'ID document'
    };
    throw new ValidationError(`Still missing: ${application.missing.map((item) => labels[item] || item).join(', ')}`);
  }

  await providerRepository.updateProvider(provider.id, provider.user_id, {
    verification_status: 'pending',
    submitted_at: new Date().toISOString(),
    rejection_reason: null,
    reviewed_at: null,
    reviewed_by: null
  });

  const admins = await providerRepository.listAdminUserIds();
  await Promise.all(admins.map((adminId) => notifySafely(adminId, {
    type: 'system',
    title: 'New provider application',
    body: `${provider.business_name} is waiting for review.`,
    relatedEntityType: 'provider',
    relatedEntityId: provider.id
  })));
  return getOwnApplication(actor);
};

export const addProviderPhoto = async (actor, { storagePath, caption }) => {
  const provider = await getOwnProvider(actor);
  await storage.assertOwnUploadedFile(storage.BUCKETS.photos, provider.user_id, 'photos', storagePath);
  if (caption != null && (typeof caption !== 'string' || caption.length > 200)) {
    throw new ValidationError('caption cannot exceed 200 characters');
  }
  const photo = await providerRepository.addGalleryPhoto(provider.id, storage.publicUrl(storagePath), caption?.trim());
  return { id: photo.id, url: photo.image_url, caption: photo.caption };
};

export const removeProviderPhoto = async (actor, photoId) => {
  const provider = await getOwnProvider(actor);
  const photo = await providerRepository.deleteGalleryPhoto(provider.id, photoId);
  await storage.removeFiles(storage.BUCKETS.photos, [storage.photoPathFromPublicUrl(photo.image_url)]);
  return { id: photo.id, removed: true };
};

const getOwnService = async (actor, serviceId) => {
  const provider = await getOwnProvider(actor);
  const service = await providerRepository.getServiceForProvider(provider.id, serviceId);
  return { provider, service };
};

export const addServicePhoto = async (actor, serviceId, storagePath) => {
  const { provider, service } = await getOwnService(actor, serviceId);
  await storage.assertOwnUploadedFile(storage.BUCKETS.photos, provider.user_id, 'photos', storagePath);
  const image = await providerRepository.addServiceImage(service.id, storage.publicUrl(storagePath));
  return { id: image.id, url: image.image_url };
};

export const removeServicePhoto = async (actor, serviceId, imageId) => {
  const { service } = await getOwnService(actor, serviceId);
  const image = await providerRepository.deleteServiceImage(service.id, imageId);
  await storage.removeFiles(storage.BUCKETS.photos, [storage.photoPathFromPublicUrl(image.image_url)]);
  return { id: image.id, removed: true };
};

/** Attach photos (and only active packages for the public) to a list of services. */
const withServiceExtras = async (services, { includeInactivePackages = false } = {}) => {
  const images = await providerRepository.listServiceImages(services.map((service) => service.id));
  return services.map((service) => ({
    ...service,
    packages: (service.packages || [])
      .filter((pkg) => includeInactivePackages || pkg.is_active)
      .sort((a, b) => a.sort_order - b.sort_order || Number(a.price) - Number(b.price)),
    photos: images
      .filter((image) => image.service_id === service.id)
      .map((image) => ({ id: image.id, url: image.image_url }))
  }));
};

/** The provider's own services, including inactive ones (works before approval too). */
export const getOwnServices = async (actor) => {
  const provider = await getOwnProvider(actor);
  return withServiceExtras(await providerRepository.listOwnServices(provider.id), { includeInactivePackages: true });
};

export const updateProviderProfile = async (actor, providerId, input) => {
  const provider = await providerRepository.getProviderById(providerId);
  assertProviderOwner(actor, provider);
  const updates = {};
  const fieldMap = {
    businessName: 'business_name',
    description: 'business_description',
    streetAddress: 'street_address',
    suburb: 'suburb',
    city: 'city',
    province: 'province',
    postalCode: 'postal_code',
    serviceRadiusKm: 'service_radius_km',
    serviceAreaRadiusKm: 'service_radius_km'
  };

  for (const [inputField, dbField] of Object.entries(fieldMap)) {
    if (input[inputField] === undefined) continue;
    const value = input[inputField];
    if (inputField === 'businessName') assertBusinessName(typeof value === 'string' ? value.trim() : '');
    if (inputField === 'description' && (typeof value !== 'string' || value.length > 5000)) {
      throw new ValidationError('description cannot exceed 5000 characters');
    }
    if (['serviceRadiusKm', 'serviceAreaRadiusKm'].includes(inputField)
        && (!Number.isInteger(value) || value < 1 || value > 50)) {
      throw new ValidationError('serviceRadiusKm must be between 1 and 50');
    }
    updates[dbField] = typeof value === 'string' ? value.trim() : value;
  }
  if (input.category !== undefined || input.categoryId !== undefined) {
    updates.primary_category_id = await resolveCategoryId(input.categoryId ?? input.category);
  }
  if (input.location !== undefined) updates.location = locationValue(input.location);
  if (input.registrationNumber !== undefined) {
    if (provider.verification_status === 'verified') {
      throw new ConflictError('The registration number of a verified business cannot be changed');
    }
    updates.business_registration_number = normaliseRegistrationNumber(input.registrationNumber);
    await assertRegistrationNumberFree(updates.business_registration_number, providerId);
  }
  if (!Object.keys(updates).length) throw new ValidationError('No editable provider fields were supplied');

  return providerRepository.updateProvider(providerId, provider.user_id, updates);
};

export const getProviderServices = async (providerId) => {
  const provider = await providerRepository.getProviderById(providerId);
  if (provider.verification_status !== 'verified' || !provider.is_active) throw new NotFoundError('Provider not found');
  return withServiceExtras(await providerRepository.getProviderServices(providerId));
};

export const createService = async (actor, providerId, input) => {
  const provider = await providerRepository.getProviderById(providerId);
  assertProviderOwner(actor, provider);
  if (provider.verification_status !== 'verified') {
    throw new ConflictError('Provider verification is required before publishing services');
  }
  const service = validateService(input);
  service.category_id = await resolveCategoryId(service.category_id);
  return providerRepository.createService({
    provider_id: providerId, currency: 'ZAR', active: true, ...service
  });
};

export const updateService = async (actor, providerId, serviceId, input) => {
  const provider = await providerRepository.getProviderById(providerId);
  assertProviderOwner(actor, provider);
  const updates = validateService(input, true);
  if (updates.category_id) updates.category_id = await resolveCategoryId(updates.category_id);
  return providerRepository.updateService(providerId, serviceId, updates);
};

export const deactivateService = async (actor, providerId, serviceId) => {
  const provider = await providerRepository.getProviderById(providerId);
  assertProviderOwner(actor, provider);
  return providerRepository.updateService(providerId, serviceId, { active: false });
};

const validatePackage = (input, partial = false) => {
  const pkg = {};
  if (!partial && (input.name === undefined || input.price === undefined)) {
    throw new ValidationError('name and price are required');
  }
  if (input.name !== undefined) {
    if (typeof input.name !== 'string' || input.name.trim().length < 2 || input.name.trim().length > 100) {
      throw new ValidationError('name must contain 2 to 100 characters');
    }
    pkg.name = input.name.trim();
  }
  if (input.description !== undefined) {
    if (input.description !== null && (typeof input.description !== 'string' || input.description.length > 2000)) {
      throw new ValidationError('description cannot exceed 2000 characters');
    }
    pkg.description = input.description?.trim() || null;
  }
  if (input.price !== undefined) {
    const price = Number(input.price);
    if (!Number.isFinite(price) || price <= 0 || price > 1000000) throw new ValidationError('price must be above 0');
    pkg.price = Math.round(price * 100) / 100;
  }
  if (input.durationMinutes !== undefined) {
    const duration = Number(input.durationMinutes);
    if (!Number.isInteger(duration) || duration < 1 || duration > 1440) {
      throw new ValidationError('durationMinutes must be between 1 and 1440');
    }
    pkg.duration_minutes = duration;
  }
  if (input.sortOrder !== undefined) {
    if (!Number.isInteger(input.sortOrder)) throw new ValidationError('sortOrder must be a whole number');
    pkg.sort_order = input.sortOrder;
  }
  if (input.isActive !== undefined) {
    if (typeof input.isActive !== 'boolean') throw new ValidationError('isActive must be a boolean');
    pkg.is_active = input.isActive;
  }
  return pkg;
};

const getOwnedPackageService = async (actor, providerId, serviceId) => {
  const provider = await providerRepository.getProviderById(providerId);
  assertProviderOwner(actor, provider);
  const service = await providerRepository.getServiceForProvider(providerId, serviceId);
  if (service.pricing_type !== 'package') {
    throw new ConflictError('Set the service pricingType to "package" before adding packages');
  }
  return service;
};

export const createPackage = async (actor, providerId, serviceId, input) => {
  const service = await getOwnedPackageService(actor, providerId, serviceId);
  return providerRepository.createPackage({ service_id: service.id, ...validatePackage(input) });
};

export const updatePackage = async (actor, providerId, serviceId, packageId, input) => {
  const service = await getOwnedPackageService(actor, providerId, serviceId);
  const updates = validatePackage(input, true);
  if (!Object.keys(updates).length) throw new ValidationError('No package fields were supplied');
  return providerRepository.updatePackage(service.id, packageId, updates);
};

/** Packages are deactivated, not deleted: old bookings keep pointing at them. */
export const deactivatePackage = async (actor, providerId, serviceId, packageId) => {
  const service = await getOwnedPackageService(actor, providerId, serviceId);
  return providerRepository.updatePackage(service.id, packageId, { is_active: false });
};

export const getAvailability = async (providerId) => {
  await providerRepository.getProviderById(providerId);
  const [weekly, timeOff] = await Promise.all([
    providerRepository.getProviderAvailability(providerId),
    providerRepository.listProviderTimeOff(providerId)
  ]);
  return { weekly, timeOff };
};

export const updateAvailability = async (actor, providerId, input) => {
  const provider = await providerRepository.getProviderById(providerId);
  assertProviderOwner(actor, provider);
  if (!Array.isArray(input.slots)) throw new ValidationError('slots must be an array');
  const seenDays = new Set();
  const slots = input.slots.map((slot) => {
    const { dayOfWeek, startTime, endTime } = slot;
    if (!Number.isInteger(dayOfWeek) || dayOfWeek < 0 || dayOfWeek > 6 || seenDays.has(dayOfWeek)) {
      throw new ValidationError('Each availability day must be unique and between 0 and 6');
    }
    if (!/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(startTime)
        || !/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(endTime)
        || startTime >= endTime) {
      throw new ValidationError('Availability times must be valid and end after start');
    }
    seenDays.add(dayOfWeek);
    return {
      dayOfWeek,
      startTime: startTime.length === 5 ? `${startTime}:00` : startTime,
      endTime: endTime.length === 5 ? `${endTime}:00` : endTime
    };
  });
  return providerRepository.replaceProviderAvailability(providerId, slots);
};
