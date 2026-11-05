/**
 * Search Service
 * Provider discovery and filtering
 */

import * as providerRepository from '../repositories/providerRepository.js';
import { AuthorizationError, NotFoundError, ValidationError } from '../utils/errors.js';

const parsePagination = (pageValue, limitValue) => {
  const page = Number.parseInt(pageValue, 10) || 1;
  const limit = Number.parseInt(limitValue, 10) || 20;
  if (!Number.isInteger(page) || !Number.isInteger(limit) || page < 1 || limit < 1 || limit > 100) {
    throw new ValidationError('page must be positive and limit must be between 1 and 100');
  }
  return { page, limit };
};

const pointToLatLng = (location) => {
  const coordinates = location?.coordinates;
  return Array.isArray(coordinates) ? { latitude: coordinates[1], longitude: coordinates[0] } : {};
};

/**
 * What a listing card needs: active services (with active packages), a photo and coordinates.
 * Never includes the owner's private details.
 */
const withListingDetails = async (providers) => {
  const ids = providers.map((provider) => provider.id);
  const [services, gallery] = await Promise.all([
    providerRepository.listActiveServicesForProviders(ids),
    providerRepository.listGallery(ids)
  ]);
  return providers.map((provider) => {
    const { location, ...rest } = provider;
    const coordinates = provider.latitude !== undefined
      ? { latitude: provider.latitude, longitude: provider.longitude }
      : pointToLatLng(location);
    return {
      ...rest,
      ...coordinates,
      verified: true, // search only returns verified, active providers
      photoUrl: gallery.find((photo) => photo.provider_id === provider.id)?.image_url ?? null,
      services: services
        .filter((service) => service.provider_id === provider.id)
        .map((service) => ({ ...service, packages: (service.packages || []).filter((pkg) => pkg.is_active) }))
    };
  });
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
  providers = providers.filter((provider) => Number(provider.rating_average || 0) >= minRating);
  const services = await providerRepository.listActiveServicesForProviders(providers.map((provider) => provider.id));
  const servicesByProvider = new Map();
  for (const service of services) {
    const list = servicesByProvider.get(service.provider_id) || [];
    list.push(service);
    servicesByProvider.set(service.provider_id, list);
  }

  let categoryId;
  if (filters.category) {
    const categories = await providerRepository.listCategories();
    const requestedCategory = String(filters.category).trim().toLowerCase();
    categoryId = categories.find((category) => (
      category.id.toLowerCase() === requestedCategory
      || category.name.trim().toLowerCase() === requestedCategory
    ))?.id;
    if (!categoryId) providers = [];
  }

  providers = providers.map((provider) => ({
    ...provider,
    services: servicesByProvider.get(provider.id) || []
  }));
  if (categoryId) {
    providers = providers.filter((provider) => provider.services.some((service) => service.category_id === categoryId));
  }
  if (Number.isFinite(maxPrice)) {
    providers = providers.filter((provider) => provider.services
      .some((service) => Number(service.base_price) <= maxPrice));
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
  return { ...result, providers: await withListingDetails(result.providers), query: normalizedQuery };
};

export const getCategories = async () => providerRepository.listCategories();

export const getFeaturedProviders = async (limitValue = 10) => {
  const limit = Number.parseInt(limitValue, 10) || 10;
  if (!Number.isInteger(limit) || limit < 1 || limit > 50) {
    throw new ValidationError('limit must be between 1 and 50');
  }
  return providerRepository.listFeaturedProviders(limit);
};

export const saveProvider = async (actor, providerId) => {
  if (actor?.role !== 'customer') throw new AuthorizationError('Only customers can save providers');
  if (typeof providerId !== 'string' || !/^[0-9a-f-]{36}$/i.test(providerId)) {
    throw new ValidationError('providerId must be a UUID');
  }
  const provider = await providerRepository.getProviderById(providerId);
  if (provider.verification_status !== 'verified' || !provider.is_active) {
    throw new NotFoundError('Provider not found');
  }
  return providerRepository.addFavorite(actor.id, providerId);
};

export const getSavedProviders = async (actor) => {
  if (actor?.role !== 'customer') throw new AuthorizationError('Only customers can list saved providers');
  const favorites = await providerRepository.listFavorites(actor.id);
  return favorites.filter(({ provider }) => (
    provider?.verification_status === 'verified' && provider.is_active
  ));
};

export const removeSavedProvider = async (actor, providerId) => {
  if (actor?.role !== 'customer') throw new AuthorizationError('Only customers can remove saved providers');
  if (typeof providerId !== 'string' || !/^[0-9a-f-]{36}$/i.test(providerId)) {
    throw new ValidationError('providerId must be a UUID');
  }
  return providerRepository.removeFavorite(actor.id, providerId);
};

export default {
  searchNearby,
  searchProviders,
  getCategories,
  getFeaturedProviders,
  saveProvider,
  getSavedProviders,
  removeSavedProvider
};
