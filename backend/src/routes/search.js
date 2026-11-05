/**
 * Search Routes
 * Handles location-based provider search and filtering
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { optionalToken, requireRole, verifyToken } from '../middleware/auth.js';
import { validateBody } from '../middleware/validation.js';
import * as searchService from '../services/searchService.js';

const router = express.Router();
const savedProviderSchema = z.object({ providerId: z.string().uuid() }).strict();

/**
 * GET /api/v1/search/nearby
 * Search for providers near a location
 * Query params: latitude, longitude, radius, category, minRating, maxPrice
 */
router.get('/nearby', optionalToken, asyncHandler(async (req, res) => {
  const result = await searchService.searchNearby(
    req.query.latitude,
    req.query.longitude,
    req.query.radius,
    {
      category: req.query.category,
      minRating: req.query.minRating,
      maxPrice: req.query.maxPrice
    }
  );
  res.status(200).json({
    success: true,
    data: result
  });
}));

/**
 * GET /api/v1/search/providers
 * Search providers by name, category, or service
 * Query params: q, category, page, limit
 */
router.get('/providers', optionalToken, asyncHandler(async (req, res) => {
  const result = await searchService.searchProviders(
    req.query.q,
    req.query.category,
    req.query.page,
    req.query.limit
  );
  res.status(200).json({
    success: true,
    data: result
  });
}));

/**
 * GET /api/v1/search/categories
 * Get all available service categories
 */
router.get('/categories', asyncHandler(async (req, res) => {
  const categories = await searchService.getCategories();
  res.status(200).json({
    success: true,
    data: { categories }
  });
}));

/**
 * GET /api/v1/search/featured
 * Get featured/recommended providers
 */
router.get('/featured', asyncHandler(async (req, res) => {
  const providers = await searchService.getFeaturedProviders(req.query.limit);
  res.status(200).json({
    success: true,
    data: { providers }
  });
}));

/**
 * POST /api/v1/search/saved
 * Save a provider to user's favorites
 */
router.post('/saved', verifyToken, requireRole('customer'), validateBody(savedProviderSchema), asyncHandler(async (req, res) => {
  const favorite = await searchService.saveProvider(req.user, req.validatedBody.providerId);
  res.status(201).json({
    success: true,
    message: 'Provider saved successfully',
    data: { favorite }
  });
}));

/**
 * GET /api/v1/search/saved
 * Get user's saved providers
 */
router.get('/saved', verifyToken, requireRole('customer'), asyncHandler(async (req, res) => {
  const providers = await searchService.getSavedProviders(req.user);
  res.status(200).json({
    success: true,
    data: { providers }
  });
}));

router.delete('/saved/:providerId', verifyToken, requireRole('customer'), asyncHandler(async (req, res) => {
  const result = await searchService.removeSavedProvider(req.user, req.params.providerId);
  res.status(200).json({ success: true, data: result });
}));

export default router;
