/**
 * Google Maps Integration
 * Location services and geocoding
 */

import axios from 'axios';
import logger from '../utils/logger.js';
import { ExternalServiceError } from '../utils/errors.js';

const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY;
const PLACES_API_URL = 'https://maps.googleapis.com/maps/api/place';
const GEOCODING_API_URL = 'https://maps.googleapis.com/maps/api/geocode';

/**
 * Search nearby places
 */
export const searchNearbyPlaces = async (latitude, longitude, type, radiusMeters = 5000) => {
  try {
    const response = await axios.get(`${PLACES_API_URL}/nearbysearch/json`, {
      params: {
        location: `${latitude},${longitude}`,
        radius: radiusMeters,
        type,
        key: GOOGLE_MAPS_API_KEY
      }
    });

    return response.data.results || [];
  } catch (error) {
    logger.error('Google Places API error:', error);
    throw new ExternalServiceError('Failed to search nearby places', 'google-maps');
  }
};

/**
 * Geocode address to coordinates
 */
export const geocodeAddress = async (address) => {
  try {
    const response = await axios.get(`${GEOCODING_API_URL}/json`, {
      params: {
        address,
        key: GOOGLE_MAPS_API_KEY
      }
    });

    if (response.data.results.length === 0) {
      return null;
    }

    const { lat, lng } = response.data.results[0].geometry.location;
    return { latitude: lat, longitude: lng };
  } catch (error) {
    logger.error('Google Geocoding API error:', error);
    throw new ExternalServiceError('Failed to geocode address', 'google-maps');
  }
};

/**
 * Get distance matrix between points
 */
export const getDistanceMatrix = async (origins, destinations) => {
  try {
    const response = await axios.get('https://maps.googleapis.com/maps/api/distancematrix/json', {
      params: {
        origins: origins.join('|'),
        destinations: destinations.join('|'),
        key: GOOGLE_MAPS_API_KEY
      }
    });

    return response.data.rows;
  } catch (error) {
    logger.error('Google Distance Matrix API error:', error);
    throw new ExternalServiceError('Failed to get distance matrix', 'google-maps');
  }
};

export default {
  searchNearbyPlaces,
  geocodeAddress,
  getDistanceMatrix
};
