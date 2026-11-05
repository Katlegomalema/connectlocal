/**
 * Provider Repository
 * Database operations for providers and services
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { ConflictError, NotFoundError } from '../utils/errors.js';

/**
 * Fetch provider profile by ID
 */
export const getProviderById = async (providerId) => {
  const { data, error } = await supabase
    .from('providers')
    .select('*')
    .eq('id', providerId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Provider not found');
  return data;
};

export const getProviderByUserId = async (userId) => {
  const { data, error } = await supabase
    .from('providers')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle();

  if (error) throw error;
  return data;
};

/** True when another business (not rejected) already uses this registration number. */
export const registrationNumberInUse = async (registrationNumber, exceptProviderId = null) => {
  let query = supabase
    .from('providers')
    .select('id', { count: 'exact', head: true })
    .eq('business_registration_number', registrationNumber)
    .neq('verification_status', 'rejected');
  if (exceptProviderId) query = query.neq('id', exceptProviderId);
  const { count, error } = await query;
  if (error) throw error;
  return (count || 0) > 0;
};

/**
 * Create new provider
 */
export const createProvider = async (providerData) => {
  const { data, error } = await supabase
    .from('providers')
    .insert(providerData)
    .select()
    .single();

  if (error?.code === '23505') {
    const detail = `${error.message} ${error.details || ''}`;
    if (detail.includes('registration_number')) {
      throw new ConflictError('This company registration number is already registered');
    }
    throw new ConflictError('A provider profile already exists for this account');
  }
  if (error) throw error;
  return data;
};

export const getServiceCategoryById = async (categoryId) => {
  const { data, error } = await supabase
    .from('service_categories')
    .select('id, name')
    .eq('id', categoryId)
    .eq('is_active', true)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Service category not found');
  return data;
};

export const getServiceCategoryByName = async (categoryName) => {
  const { data, error } = await supabase
    .from('service_categories')
    .select('id, name')
    .ilike('name', categoryName)
    .eq('is_active', true)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Service category not found');
  return data;
};

/**
 * Fetch services offered by provider
 */
const PACKAGE_COLUMNS = 'id, service_id, name, description, price, duration_minutes, sort_order, is_active';

export const getProviderServices = async (providerId) => {
  const { data, error } = await supabase
    .from('services')
    .select(`*, packages:service_packages(${PACKAGE_COLUMNS})`)
    .eq('provider_id', providerId)
    .eq('active', true)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return (data || []).map((service) => ({
    ...service,
    packages: (service.packages || [])
      .filter((pkg) => pkg.is_active)
      .sort((a, b) => a.sort_order - b.sort_order || Number(a.price) - Number(b.price))
  }));
};

export const getServiceForProvider = async (providerId, serviceId) => {
  const { data, error } = await supabase
    .from('services')
    .select('id, provider_id, pricing_type, active')
    .eq('id', serviceId)
    .eq('provider_id', providerId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Service not found');
  return data;
};

export const createPackage = async (pkg) => {
  const { data, error } = await supabase
    .from('service_packages')
    .insert(pkg)
    .select(PACKAGE_COLUMNS)
    .single();

  if (error?.code === '23505') throw new ConflictError('This service already has a package with that name');
  if (error) throw error;
  return data;
};

export const updatePackage = async (serviceId, packageId, updates) => {
  const { data, error } = await supabase
    .from('service_packages')
    .update(updates)
    .eq('id', packageId)
    .eq('service_id', serviceId)
    .select(PACKAGE_COLUMNS)
    .maybeSingle();

  if (error?.code === '23505') throw new ConflictError('This service already has a package with that name');
  if (error) throw error;
  if (!data) throw new NotFoundError('Package not found');
  return data;
};

/**
 * Create service listing
 */
export const createService = async (serviceData) => {
  const { data, error } = await supabase
    .from('services')
    .insert(serviceData)
    .select()
    .single();

  if (error) throw error;
  return data;
};

/** Active admins (to notify them about new applications). */
export const listAdminUserIds = async () => {
  const { data, error } = await supabase
    .from('users')
    .select('id')
    .eq('role', 'admin')
    .eq('is_active', true)
    .is('deleted_at', null);

  if (error) throw error;
  return (data || []).map((row) => row.id);
};

const DOCUMENT_COLUMNS = 'id, provider_id, document_type, approval_status, rejection_reason, uploaded_at, storage_path, document_url';

export const listProviderDocuments = async (providerId) => {
  const { data, error } = await supabase
    .from('provider_documents')
    .select(DOCUMENT_COLUMNS)
    .eq('provider_id', providerId)
    .order('uploaded_at', { ascending: false });

  if (error) throw error;
  return data || [];
};

/**
 * Save a document. One current document per type (except 'other'): a new upload replaces the old row,
 * goes back to 'pending', and the old file path is returned so it can be deleted.
 */
export const saveProviderDocument = async (providerId, documentType, storagePath) => {
  const values = {
    provider_id: providerId,
    document_type: documentType,
    storage_path: storagePath,
    document_url: null,
    approval_status: 'pending',
    rejection_reason: null,
    reviewed_by: null,
    reviewed_at: null,
    uploaded_at: new Date().toISOString()
  };

  let existing = null;
  if (documentType !== 'other') {
    const { data, error } = await supabase
      .from('provider_documents')
      .select('id, storage_path')
      .eq('provider_id', providerId)
      .eq('document_type', documentType)
      .maybeSingle();
    if (error) throw error;
    existing = data;
  }

  const request = existing
    ? supabase.from('provider_documents').update(values).eq('id', existing.id)
    : supabase.from('provider_documents').insert(values);
  const { data, error } = await request.select(DOCUMENT_COLUMNS).single();
  if (error) throw error;
  return { document: data, replacedPath: existing?.storage_path || null };
};

const GALLERY_COLUMNS = 'id, provider_id, image_url, caption, sort_order, created_at';

export const listGallery = async (providerIds) => {
  const ids = Array.isArray(providerIds) ? providerIds : [providerIds];
  if (!ids.length) return [];
  const { data, error } = await supabase
    .from('provider_gallery')
    .select(GALLERY_COLUMNS)
    .in('provider_id', ids)
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: true });

  if (error) throw error;
  return data || [];
};

export const addGalleryPhoto = async (providerId, imageUrl, caption) => {
  const { data, error } = await supabase
    .from('provider_gallery')
    .insert({ provider_id: providerId, image_url: imageUrl, caption: caption || null })
    .select(GALLERY_COLUMNS)
    .single();

  if (error) throw error;
  return data;
};

export const deleteGalleryPhoto = async (providerId, photoId) => {
  const { data, error } = await supabase
    .from('provider_gallery')
    .delete()
    .eq('id', photoId)
    .eq('provider_id', providerId)
    .select(GALLERY_COLUMNS)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Photo not found');
  return data;
};

export const listServiceImages = async (serviceIds) => {
  if (!serviceIds.length) return [];
  const { data, error } = await supabase
    .from('service_images')
    .select('id, service_id, image_url, sort_order')
    .in('service_id', serviceIds)
    .order('sort_order', { ascending: true });

  if (error) throw error;
  return data || [];
};

export const addServiceImage = async (serviceId, imageUrl) => {
  const { data, error } = await supabase
    .from('service_images')
    .insert({ service_id: serviceId, image_url: imageUrl })
    .select('id, service_id, image_url, sort_order')
    .single();

  if (error) throw error;
  return data;
};

export const deleteServiceImage = async (serviceId, imageId) => {
  const { data, error } = await supabase
    .from('service_images')
    .delete()
    .eq('id', imageId)
    .eq('service_id', serviceId)
    .select('id, service_id, image_url')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Photo not found');
  return data;
};

/** All services of one provider (owner view: inactive too), with packages. */
export const listOwnServices = async (providerId) => {
  const { data, error } = await supabase
    .from('services')
    .select('*, packages:service_packages(id, service_id, name, description, price, duration_minutes, sort_order, is_active)')
    .eq('provider_id', providerId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data || [];
};

export const updateProvider = async (providerId, userId, updates) => {
  const { data, error } = await supabase
    .from('providers')
    .update(updates)
    .eq('id', providerId)
    .eq('user_id', userId)
    .select('*')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Provider not found');
  return data;
};

export const updateService = async (providerId, serviceId, updates) => {
  const { data, error } = await supabase
    .from('services')
    .update(updates)
    .eq('id', serviceId)
    .eq('provider_id', providerId)
    .select('*')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Service not found');
  return data;
};

/**
 * Search providers by location
 */
export const searchProvidersByLocation = async (latitude, longitude, radiusKm = 50) => {
  const { data, error } = await supabase.rpc('search_nearby_providers', {
    search_latitude: latitude,
    search_longitude: longitude,
    search_radius_km: radiusKm
  });

  if (error) throw error;
  return data || [];
};

export const searchProvidersByText = async (queryText, { category, page, limit }) => {
  let query = supabase
    .from('providers')
    .select('id, user_id, business_name, business_description, street_address, suburb, city, province, service_radius_km, '
      + 'rating_average, rating_count, location, offers_visit, offers_house_call, slot_minutes', { count: 'exact' })
    .eq('verification_status', 'verified')
    .eq('is_active', true);

  if (queryText) {
    const safeText = queryText.replace(/[^a-zA-Z0-9\s'-]/g, ' ').trim().slice(0, 100);
    if (safeText) {
      query = query.or(`business_name.ilike.%${safeText}%,business_description.ilike.%${safeText}%`);
    }
  }
  if (category) {
    let categoryId = category;
    if (!/^[0-9a-f-]{36}$/i.test(category)) {
      const { data: categoryRow, error: categoryError } = await supabase
        .from('service_categories')
        .select('id')
        .ilike('name', category)
        .eq('is_active', true)
        .maybeSingle();
      if (categoryError) throw categoryError;
      if (!categoryRow) {
        return {
          providers: [], total: 0, page, pages: 0
        };
      }
      categoryId = categoryRow.id;
    }
    const { data: services, error: serviceError } = await supabase
      .from('services')
      .select('provider_id')
      .eq('category_id', categoryId)
      .eq('active', true);
    if (serviceError) throw serviceError;
    const providerIds = [...new Set((services || []).map((service) => service.provider_id))];
    if (!providerIds.length) {
      return {
        providers: [], total: 0, page, pages: 0
      };
    }
    query = query.in('id', providerIds);
  }

  const offset = (page - 1) * limit;
  const { data, error, count } = await query
    .order('rating_average', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  return {
    providers: data || [], total: count || 0, page, pages: Math.ceil((count || 0) / limit)
  };
};

export const listCategories = async () => {
  const { data, error } = await supabase
    .from('service_categories')
    .select('id, name, icon')
    .eq('is_active', true)
    .order('name');

  if (error) throw error;
  return data || [];
};

export const listFeaturedProviders = async (limit = 10) => {
  const { data, error } = await supabase
    .from('providers')
    .select('id, user_id, business_name, business_description, city, province, rating_average, rating_count')
    .eq('verification_status', 'verified')
    .eq('is_active', true)
    .order('rating_average', { ascending: false })
    .order('rating_count', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data || [];
};

export const listActiveServicesForProviders = async (providerIds) => {
  if (!providerIds.length) return [];
  const { data, error } = await supabase
    .from('services')
    .select('id, provider_id, service_name, category_id, base_price, currency, duration_minutes, pricing_type, '
      + 'packages:service_packages(id, name, price, description, duration_minutes, sort_order, is_active)')
    .in('provider_id', providerIds)
    .eq('active', true);

  if (error) throw error;
  return data || [];
};

export const getProviderAvailability = async (providerId) => {
  const { data, error } = await supabase
    .from('provider_availability')
    .select('id, provider_id, day_of_week, start_time, end_time')
    .eq('provider_id', providerId)
    .order('day_of_week');
  if (error) throw error;
  return data || [];
};

export const replaceProviderAvailability = async (providerId, slots) => {
  const existing = await getProviderAvailability(providerId);
  const existingByDay = new Map(existing.map((slot) => [slot.day_of_week, slot]));
  const desiredDays = slots.map((slot) => slot.dayOfWeek);
  const saved = [];

  for (const slot of slots) {
    const values = {
      provider_id: providerId,
      day_of_week: slot.dayOfWeek,
      start_time: slot.startTime,
      end_time: slot.endTime
    };
    const existingSlot = existingByDay.get(slot.dayOfWeek);
    const request = existingSlot
      ? supabase.from('provider_availability').update(values).eq('id', existingSlot.id)
      : supabase.from('provider_availability').insert(values);
    // eslint-disable-next-line no-await-in-loop -- at most 7 slots, saved in order
    const { data, error } = await request.select('*').single();
    if (error) throw error;
    saved.push(data);
  }

  let removeQuery = supabase.from('provider_availability').delete().eq('provider_id', providerId);
  if (desiredDays.length) removeQuery = removeQuery.not('day_of_week', 'in', `(${desiredDays.join(',')})`);
  const { error } = await removeQuery;
  if (error) throw error;
  return saved.sort((left, right) => left.day_of_week - right.day_of_week);
};

export const listProviderTimeOff = async (providerId, startAt, endAt) => {
  let query = supabase
    .from('provider_time_off')
    .select('id, start_at, end_at, reason')
    .eq('provider_id', providerId)
    .order('start_at');
  if (startAt) query = query.gte('end_at', startAt);
  if (endAt) query = query.lte('start_at', endAt);
  const { data, error } = await query;
  if (error) throw error;
  return data || [];
};

export const createProviderTimeOff = async (providerId, timeOff) => {
  const { data, error } = await supabase
    .from('provider_time_off')
    .insert({ provider_id: providerId, ...timeOff })
    .select('*')
    .single();
  if (error) throw error;
  return data;
};

export const addFavorite = async (userId, providerId) => {
  const { data, error } = await supabase
    .from('favorites')
    .insert({ user_id: userId, provider_id: providerId })
    .select('*')
    .single();
  if (error?.code === '23505') return { user_id: userId, provider_id: providerId, alreadySaved: true };
  if (error) throw error;
  return data;
};

export const listFavorites = async (userId) => {
  const { data, error } = await supabase
    .from('favorites')
    .select('provider_id, created_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });
  if (error) throw error;
  const favorites = data || [];
  if (!favorites.length) return [];
  const providerIds = favorites.map((favorite) => favorite.provider_id);
  const { data: providers, error: providerError } = await supabase
    .from('providers')
    .select('id, business_name, business_description, city, province, rating_average, rating_count, verification_status, is_active')
    .in('id', providerIds);
  if (providerError) throw providerError;
  const providerById = new Map((providers || []).map((provider) => [provider.id, provider]));
  return favorites.map((favorite) => ({
    ...favorite,
    provider: providerById.get(favorite.provider_id) || null
  }));
};

export const removeFavorite = async (userId, providerId) => {
  const { data, error } = await supabase
    .from('favorites')
    .delete()
    .eq('user_id', userId)
    .eq('provider_id', providerId)
    .select('provider_id')
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new NotFoundError('Saved provider not found');
  return { removed: true };
};

export default {
  getProviderById,
  registrationNumberInUse,
  getProviderByUserId,
  getServiceCategoryById,
  getServiceCategoryByName,
  createProvider,
  listAdminUserIds,
  listProviderDocuments,
  saveProviderDocument,
  listGallery,
  addGalleryPhoto,
  deleteGalleryPhoto,
  listServiceImages,
  addServiceImage,
  deleteServiceImage,
  listOwnServices,
  getProviderServices,
  getServiceForProvider,
  createPackage,
  updatePackage,
  createService,
  updateProvider,
  updateService,
  searchProvidersByLocation,
  searchProvidersByText,
  listCategories,
  listFeaturedProviders,
  listActiveServicesForProviders,
  getProviderAvailability,
  replaceProviderAvailability,
  listProviderTimeOff,
  createProviderTimeOff,
  addFavorite,
  listFavorites,
  removeFavorite
};
