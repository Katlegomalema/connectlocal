/**
 * Provider Repository
 * Database operations for providers and services
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { AppError, NotFoundError } from '../utils/errors.js';

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

/**
 * Create new provider
 */
export const createProvider = async (providerData) => {
  const { data, error } = await supabase
    .from('providers')
    .insert(providerData)
    .select()
    .single();

  if (error) throw error;
  return data;
};

/**
 * Fetch services offered by provider
 */
export const getProviderServices = async (providerId) => {
  const { data, error } = await supabase
    .from('services')
    .select('*')
    .eq('provider_id', providerId)
    .eq('active', true)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data || [];
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
  throw new AppError('Nearby search requires provider coordinates or a configured Maps geocoder; neither is available in the live schema yet', 501, 'NOT_IMPLEMENTED');
};

export const searchProvidersByText = async (queryText, { category, page, limit }) => {
  let query = supabase
    .from('providers')
    .select('id, user_id, business_name, business_description, city, province, service_radius_km, rating_average, rating_count', { count: 'exact' })
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
      if (!categoryRow) return { providers: [], total: 0, page, pages: 0 };
      categoryId = categoryRow.id;
    }
    const { data: services, error: serviceError } = await supabase
      .from('services')
      .select('provider_id')
      .eq('category_id', categoryId)
      .eq('active', true);
    if (serviceError) throw serviceError;
    const providerIds = [...new Set((services || []).map((service) => service.provider_id))];
    if (!providerIds.length) return { providers: [], total: 0, page, pages: 0 };
    query = query.in('id', providerIds);
  }

  const offset = (page - 1) * limit;
  const { data, error, count } = await query
    .order('average_rating', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  return { providers: data || [], total: count || 0, page, pages: Math.ceil((count || 0) / limit) };
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
    .select('id, provider_id, service_name, category_id, base_price, currency, duration_minutes')
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
  getProviderByUserId,
  createProvider,
  getProviderServices,
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
