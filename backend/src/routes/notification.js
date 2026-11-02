/**
 * Notification Routes
 * Authenticated in-app notification center
 */

import express from 'express';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken } from '../middleware/auth.js';
import * as notificationService from '../services/notificationService.js';

const router = express.Router();

router.get('/', verifyToken, asyncHandler(async (req, res) => {
  const result = await notificationService.listInAppNotifications(req.user, req.query);
  res.status(200).json({ success: true, data: result });
}));

router.patch('/read-all', verifyToken, asyncHandler(async (req, res) => {
  const result = await notificationService.markAllAsRead(req.user);
  res.status(200).json({ success: true, data: result });
}));

router.patch('/:id/read', verifyToken, asyncHandler(async (req, res) => {
  const notification = await notificationService.markAsRead(req.user, req.params.id);
  res.status(200).json({ success: true, data: { notification } });
}));

router.delete('/:id', verifyToken, asyncHandler(async (req, res) => {
  await notificationService.deleteNotification(req.user, req.params.id);
  res.status(204).send();
}));

export default router;