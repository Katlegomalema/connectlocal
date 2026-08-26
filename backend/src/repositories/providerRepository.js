/**
 * Provider Repository
 * Database operations for providers and services
 */

import { supabase } from '../config/supabase.js';
import logger from '../utils/logger.js';
import { NotFoundError } from '../utils/errors.js';

/**
 * Fetch provider profile by ID
 */
export const getProviderById = async (providerId) => {
  try {
    const { data, error } = await supabase
      .from('providers')
      .select('*')
      .eq('id', providerId)
      .single();

    if (error) {
      throw new NotFoundError('Provider not found');
    }

    return data;
  } catch (error) {
    logger.error('Error fetching provider:', error);
    throw error;
  }
};

/**
 * Create new provider
 */
export const createProvider = async (providerData) => {
  try {
    const { data, error } = await supabase
      .from('providers')
      .insert([providerData])
      .select()
      .single();

    if (error) throw error;

    return data;
  } catch (error) {
    logger.error('Error creating provider:', error);
    throw error;
  }
};

/**
 * Fetch services offered by provider
 */
export const getProviderServices = async (providerId) => {
  try {
    const { data, error } = await supabase
      .from('services')
      .select('*')
      .eq('provider_id', providerId)
      .eq('is_active', true);

    if (error) throw error;

    return data || [];
  } catch (error) {
    logger.error('Error fetching provider services:', error);
    throw error;
  }
};

/**
 * Create service listing
 */
export const createService = async (serviceData) => {
  try {
    const { data, error } = await supabase
      .from('services')
      .insert([serviceData])
      .select()
      .single();

    if (error) throw error;

    return data;
  } catch (error) {
    logger.error('Error creating service:', error);
    throw error;
  }
};

/**
 * Search providers by location
 */
export const searchProvidersByLocation = async (latitude, longitude, radiusKm = 50) => {
  try {
    // PostGIS query using Supabase RPC
    const { data, error } = await supabase.rpc('search_providers_nearby', {
      lat: latitude,
      lng: longitude,
      radius_km: radiusKm
    });

    if (error) throw error;

    return data || [];
  } catch (error) {
    logger.error('Error searching providers:', error);
    throw error;
  }
};

export default {
  getProviderById,
  createProvider,
  getProviderServices,
  createService,
  searchProvidersByLocation
};
