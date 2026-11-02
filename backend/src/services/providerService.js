/**
 * Provider Service
 * Provider profiles and service catalogue operations
 */

import * as providerRepository from '../repositories/providerRepository.js';
import { AuthorizationError, ConflictError, NotFoundError, ValidationError } from '../utils/errors.js';

const providerProfileFields = [
  'id', 'business_name', 'business_description', 'street_address', 'suburb',
  'city', 'province', 'postal_code', 'service_radius_km',
  'verification_status', 'rating_average', 'rating_count'
];

const assertProviderOwner = (actor, provider) => {
  if (actor.role !== 'admin' && (actor.role !== 'provider' || provider.user_id !== actor.id)) {
    throw new AuthorizationError('You do not manage this provider profile');
  }
};

const validateService = (input, partial = false) => {
  const service = {};
  const fields = ['name', 'description', 'categoryId', 'price', 'currency', 'durationMinutes', 'minNoticeHours', 'active'];
  if (!partial && (!input.name || !input.categoryId || input.price === undefined || input.durationMinutes === undefined)) {
    throw new ValidationError('name, categoryId, price, and durationMinutes are required');
  }
  if (input.name !== undefined) {
    if (typeof input.name !== 'string' || input.name.trim().length < 2 || input.name.trim().length > 150) throw new ValidationError('name must contain 2 to 150 characters');
    service.service_name = input.name.trim();
  }
  if (input.description !== undefined) {
    if (typeof input.description !== 'string' || input.description.length > 5000) throw new ValidationError('description cannot exceed 5000 characters');
    service.description = input.description.trim() || null;
  }
  if (input.categoryId !== undefined) {
    if (typeof input.categoryId !== 'string' || !/^[0-9a-f-]{36}$/i.test(input.categoryId)) throw new ValidationError('categoryId must be a UUID');
    service.category_id = input.categoryId;
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
  if (input.active !== undefined) {
    if (typeof input.active !== 'boolean') throw new ValidationError('active must be a boolean');
    service.active = input.active;
  }
  const unknownFields = Object.keys(input).filter((key) => !fields.includes(key));
  if (unknownFields.length) throw new ValidationError(`Unsupported service fields: ${unknownFields.join(', ')}`);
  return service;
};

export const getPublicProvider = async (providerId) => {
  const provider = await providerRepository.getProviderById(providerId);
  if (provider.verification_status !== 'verified' || !provider.is_active) throw new NotFoundError('Provider not found');
  return Object.fromEntries(providerProfileFields.map((field) => [field, provider[field] ?? null]));
};

export const registerProvider = async (actor, input) => {
  if (actor?.role !== 'provider') throw new AuthorizationError('Only provider accounts can create provider profiles');
  const existing = await providerRepository.getProviderByUserId(actor.id);
  if (existing) throw new ConflictError('A provider profile already exists for this account');
  const businessName = input.businessName?.trim();
  const streetAddress = input.streetAddress?.trim();
  const city = input.city?.trim();
  const province = input.province?.trim();
  const radius = input.serviceRadiusKm ?? 10;

  if (!businessName || businessName.length < 2 || businessName.length > 150) {
    throw new ValidationError('businessName must contain between 2 and 150 characters');
  }
  if (!streetAddress || streetAddress.length > 150 || !city || !province) throw new ValidationError('streetAddress, city, and province are required');
  if (!Number.isInteger(radius) || radius < 1 || radius > 50) {
    throw new ValidationError('serviceRadiusKm must be between 1 and 50');
  }
  if (input.description != null && (typeof input.description !== 'string' || input.description.length > 5000)) {
    throw new ValidationError('description cannot exceed 5000 characters');
  }

  return providerRepository.createProvider({
    user_id: actor.id,
    business_name: businessName,
    business_description: input.description?.trim() || null,
    street_address: streetAddress,
    suburb: input.suburb?.trim() || null,
    city,
    province,
    postal_code: input.postalCode?.trim() || null,
    service_radius_km: radius,
    verification_status: 'pending',
    rating_average: 0,
    rating_count: 0,
    is_active: true
  });
};

export const submitVerification = async (actor, providerId, documentUrl) => {
  const provider = await providerRepository.getProviderById(providerId);
  assertProviderOwner(actor, provider);
  if (typeof documentUrl !== 'string' || !/^https:\/\//i.test(documentUrl)) {
    throw new ValidationError('A secure verification document URL is required');
  }
  return providerRepository.createProviderDocument(providerId, documentUrl, 'business');
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
    serviceRadiusKm: 'service_radius_km'
  };

  for (const [inputField, dbField] of Object.entries(fieldMap)) {
    if (input[inputField] === undefined) continue;
    const value = input[inputField];
    if (inputField === 'businessName' && (typeof value !== 'string' || value.trim().length < 2 || value.length > 150)) {
      throw new ValidationError('businessName must contain between 2 and 150 characters');
    }
    if (inputField === 'description' && (typeof value !== 'string' || value.length > 5000)) {
      throw new ValidationError('description cannot exceed 5000 characters');
    }
    if (inputField === 'serviceRadiusKm' && (!Number.isInteger(value) || value < 1 || value > 50)) {
      throw new ValidationError('serviceRadiusKm must be between 1 and 50');
    }
    updates[dbField] = typeof value === 'string' ? value.trim() : value;
  }
  if (!Object.keys(updates).length) throw new ValidationError('No editable provider fields were supplied');

  return providerRepository.updateProvider(providerId, provider.user_id, updates);
};

export const getProviderServices = async (providerId) => {
  const provider = await providerRepository.getProviderById(providerId);
  if (provider.verification_status !== 'verified' || !provider.is_active) throw new NotFoundError('Provider not found');
  return providerRepository.getProviderServices(providerId);
};

export const createService = async (actor, providerId, input) => {
  const provider = await providerRepository.getProviderById(providerId);
  assertProviderOwner(actor, provider);
  const service = validateService(input);
  await providerRepository.getServiceCategoryById(service.category_id);
  return providerRepository.createService({ provider_id: providerId, currency: 'ZAR', active: true, ...service });
};

export const updateService = async (actor, providerId, serviceId, input) => {
  const provider = await providerRepository.getProviderById(providerId);
  assertProviderOwner(actor, provider);
  const updates = validateService(input, true);
  if (updates.category_id) await providerRepository.getServiceCategoryById(updates.category_id);
  return providerRepository.updateService(providerId, serviceId, updates);
};

export const deactivateService = async (actor, providerId, serviceId) => {
  const provider = await providerRepository.getProviderById(providerId);
  assertProviderOwner(actor, provider);
  return providerRepository.updateService(providerId, serviceId, { active: false });
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