/**
 * Search Service
 * Provider discovery and filtering
 */

import * as providerRepository from '../repositories/providerRepository.js';
import { AppError, ValidationError } from '../utils/errors.js';

const parsePagination = (pageValue, limitValue) => {
  const page = Number.parseInt(pageValue, 10) || 1;
  const limit = Number.parseInt(limitValue, 10) || 20;
  if (!Number.isInteger(page) || !Number.isInteger(limit) || page < 1 || limit < 1 || limit > 100) {
    throw new ValidationError('page must be positive and limit must be between 1 and 100');
  }
  return { page, limit };
};

export const searchNearby = async (latitudeValue, longitudeValue, radiusValue = 50, filters = {}) => {
  const latitude = Number(latitudeValue);
  const longitude = Number(longitudeValue);
  const radiusKm = Number(radiusValue);
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90
      || !Number.isFinite(longitude) || longitude < -180 || longitude > 180
      || !Number.isFinite(radiusKm) || radiusKm < 1 || radiusKm > 50) {
    throw new ValidationError('Valid latitude, longitude, and radius (1 to 50 km) are required');
  }

  const minRating = filters.minRating === undefined ? 0 : Number(filters.minRating);
  const maxPrice = filters.maxPrice === undefined ? Infinity : Number(filters.maxPrice);
  if (!Number.isFinite(minRating) || minRating < 0 || minRating > 5
      || (filters.maxPrice !== undefined && (!Number.isFinite(maxPrice) || maxPrice < 0))) {
    throw new ValidationError('Invalid rating or price filter');
  }

  let providers = await providerRepository.searchProvidersByLocation(latitude, longitude, radiusKm);
  providers = providers.filter((provider) => Number(provider.average_rating || 0) >= minRating);
  const services = await providerRepository.listActiveServicesForProviders(providers.map((provider) => provider.id));
  const servicesByProvider = new Map();
  for (const service of services) {
    const list = servicesByProvider.get(service.provider_id) || [];
    list.push(service);
    servicesByProvider.set(service.provider_id, list);
  }

  providers = providers.map((provider) => ({
    ...provider,
    services: servicesByProvider.get(provider.id) || []
  }));
  if (filters.category) {
    providers = providers.filter((provider) => provider.services.some((service) => service.category === filters.category));
  }
  if (Number.isFinite(maxPrice)) {
    providers = providers.filter((provider) => provider.services.some((service) => Number(service.price) <= maxPrice));
  }

  return {
    providers,
    count: providers.length,
    searchCenter: { latitude, longitude },
    radiusKm
  };
};

export const searchProviders = async (query, category, pageValue, limitValue) => {
  const { page, limit } = parsePagination(pageValue, limitValue);
  const normalizedQuery = typeof query === 'string' ? query.trim().slice(0, 100) : '';
  const result = await providerRepository.searchProvidersByText(normalizedQuery, { category, page, limit });
  return { ...result, query: normalizedQuery };
};

export const getCategories = async () => providerRepository.listCategories();

export const getFeaturedProviders = async (limitValue = 10) => {
  const limit = Number.parseInt(limitValue, 10) || 10;
  if (!Number.isInteger(limit) || limit < 1 || limit > 50) {
    throw new ValidationError('limit must be between 1 and 50');
  }
  return providerRepository.listFeaturedProviders(limit);
};

export const saveProvider = async () => {
  throw new AppError('Saved providers are unavailable until a favorites table is added', 501, 'NOT_IMPLEMENTED');
};

export const getSavedProviders = async () => {
  throw new AppError('Saved providers are unavailable until a favorites table is added', 501, 'NOT_IMPLEMENTED');
};

export default {
  searchNearby,
  searchProviders,
  getCategories,
  getFeaturedProviders,
  saveProvider,
  getSavedProviders
};
