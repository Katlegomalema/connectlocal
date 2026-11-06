/**
 * Upload Routes
 *
 *   POST /api/v1/uploads/sign   (provider)   { purpose, contentType }
 *     -> { bucket, path, uploadUrl, method: 'PUT', headers, maxBytes, publicUrl? }
 *
 * The app then PUTs the file bytes to uploadUrl (with the Content-Type header) and passes `path` to the
 * endpoint that uses it, e.g. POST /providers/me/documents or POST /providers/me/photos.
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken, requireRole } from '../middleware/auth.js';
import { validateBody } from '../middleware/validation.js';
import * as storage from '../integrations/storage.js';

const router = express.Router();

const signSchema = z.object({
  purpose: z.enum(Object.keys(storage.UPLOAD_PURPOSES)),
  contentType: z.string().min(3).max(100)
}).strict();

router.post('/sign', verifyToken, requireRole('provider'), validateBody(signSchema), asyncHandler(async (req, res) => {
  const upload = await storage.createUploadUrl(req.user.id, req.validatedBody.purpose, req.validatedBody.contentType);
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, data: upload });
}));

export default router;
