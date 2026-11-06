/**
 * Common Validation Utilities
 * Reusable validation functions using Zod
 */

import { z } from 'zod';

// Email validation
export const emailSchema = z.string().email('Invalid email address');

// Phone validation (international format)
export const phoneSchema = z.string().regex(/^\+[1-9]\d{7,14}$/, 'Phone number must use E.164 format');

// Password validation
export const passwordSchema = z.string()
  .min(8, 'Password must be at least 8 characters')
  .regex(/[A-Z]/, 'Password must contain an uppercase letter')
  .regex(/[a-z]/, 'Password must contain a lowercase letter')
  .regex(/[0-9]/, 'Password must contain a number')
  .regex(/[^A-Za-z0-9]/, 'Password must contain a special character');

// Pagination validation
export const paginationSchema = z.object({
  page: z.number().int().positive().default(1),
  limit: z.number().int().min(1).max(100)
    .default(20)
});

// Coordinates validation
export const coordinatesSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180)
});

// Date validation
export const futureDate = z.coerce.date()
  .refine((date) => date > new Date(), 'Date must be in the future');

// Service category validation
export const serviceCategorySchema = z.enum([
  'plumbing',
  'electrical',
  'tutoring',
  'cleaning',
  'automotive',
  'haircare',
  'landscaping',
  'personal_training',
  'photography',
  'handyman',
  'other'
]);

// Booking status validation
export const bookingStatusSchema = z.enum([
  'pending',
  'confirmed',
  'in_progress',
  'completed',
  'cancelled',
  'declined'
]);

// Rating validation
export const ratingSchema = z.number().int().min(1).max(5);

// User role validation
export const userRoleSchema = z.enum(['customer', 'provider', 'admin']);
