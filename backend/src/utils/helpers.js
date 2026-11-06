/**
 * Helper Utility Functions
 * Common utility functions used across the application
 */

/**
 * Generate a random string of specified length
 */
export const generateRandomString = (length = 16) => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
};

/**
 * Calculate distance between two coordinates (haversine formula)
 */
export const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371; // Earth's radius in kilometers
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
    + Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180))
    * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

/**
 * Format time slot as a readable string
 */
export const formatTimeSlot = (startTime, endTime) => {
  const start = new Date(startTime).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
  const end = new Date(endTime).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
  return `${start} - ${end}`;
};

/**
 * Check if a time slot is available
 */
export const isTimeSlotAvailable = (requestStart, requestEnd, existingSlots) => !existingSlots.some((slot) => {
  const slotStart = new Date(slot.start_time);
  const slotEnd = new Date(slot.end_time);
  return requestStart < slotEnd && requestEnd > slotStart;
});

/**
 * Parse query parameters for filtering
 */
export const parseQueryFilters = (query) => {
  const filters = {};
  if (query.category) filters.category = query.category;
  if (query.minRating) filters.minRating = parseFloat(query.minRating);
  if (query.maxPrice) filters.maxPrice = parseFloat(query.maxPrice);
  if (query.searchTerm) filters.searchTerm = query.searchTerm;
  return filters;
};

/**
 * Sanitize user input
 */
export const sanitizeInput = (input) => {
  if (typeof input !== 'string') return input;
  return input.trim().replace(/[<>]/g, '');
};

/**
 * Calculate booking price with taxes
 */
export const calculateBookingTotal = (basePrice, taxRate = 0.15) => {
  const tax = basePrice * taxRate;
  return {
    basePrice,
    tax,
    total: basePrice + tax
  };
};

/**
 * Check if email is from verified domain
 */
export const isVerifiedDomain = (email, verifiedDomains = []) => {
  const domain = email.split('@')[1];
  return verifiedDomains.includes(domain);
};
