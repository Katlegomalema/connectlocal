/**
 * Validators Utility Tests
 * Tests for validation schemas
 */

import {
  emailSchema,
  phoneSchema,
  passwordSchema,
  coordinatesSchema,
  ratingSchema
} from '../../src/utils/validators.js';

describe('Validators', () => {
  describe('emailSchema', () => {
    test('should validate correct email', async () => {
      const result = await emailSchema.parseAsync('test@example.com');
      expect(result).toBe('test@example.com');
    });

    test('should reject invalid email', async () => {
      await expect(emailSchema.parseAsync('invalid-email')).rejects.toThrow();
    });
  });

  describe('phoneSchema', () => {
    test('should validate international phone number', async () => {
      const result = await phoneSchema.parseAsync('+27123456789');
      expect(result).toBe('+27123456789');
    });

    test('should reject invalid phone number', async () => {
      await expect(phoneSchema.parseAsync('123')).rejects.toThrow();
    });
  });

  describe('passwordSchema', () => {
    test('should validate strong password', async () => {
      const result = await passwordSchema.parseAsync('SecurePass123!');
      expect(result).toBe('SecurePass123!');
    });

    test('should reject weak password', async () => {
      await expect(passwordSchema.parseAsync('weak')).rejects.toThrow();
    });
  });

  describe('coordinatesSchema', () => {
    test('should validate valid coordinates', async () => {
      const coords = { latitude: -33.9249, longitude: 18.4241 };
      const result = await coordinatesSchema.parseAsync(coords);
      expect(result).toEqual(coords);
    });

    test('should reject invalid latitude', async () => {
      await expect(coordinatesSchema.parseAsync({
        latitude: 91,
        longitude: 0
      })).rejects.toThrow();
    });
  });

  describe('ratingSchema', () => {
    test('should accept rating between 1-5', async () => {
      for (let i = 1; i <= 5; i++) {
        const result = await ratingSchema.parseAsync(i);
        expect(result).toBe(i);
      }
    });

    test('should reject rating outside 1-5', async () => {
      await expect(ratingSchema.parseAsync(0)).rejects.toThrow();
      await expect(ratingSchema.parseAsync(6)).rejects.toThrow();
    });
  });
});
