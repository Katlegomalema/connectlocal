/**
 * Messaging Routes
 * Handles real-time and persistent messaging between users
 */

import express from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken } from '../middleware/auth.js';
import { validateBody } from '../middleware/validation.js';
import * as messageService from '../services/messageService.js';
import { ValidationError } from '../utils/errors.js';

const router = express.Router();
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const sendMessageSchema = z.object({
  conversationId: z.string().uuid().optional(),
  receiverId: z.string().uuid().optional(),
  bookingId: z.string().uuid().optional(),
  body: z.string().min(1).max(2000).optional(),
  messageText: z.string().min(1).max(2000).optional()
}).strict().refine((value) => value.body || value.messageText, 'body or messageText is required');
const conversationSchema = z.object({
  otherUserId: z.string().min(1).optional(),
  bookingId: z.string().min(1).optional()
}).strict();

/**
 * POST /api/v1/messages
 * Send a message to a user or booking context
 */
router.post('/', verifyToken, validateBody(sendMessageSchema), asyncHandler(async (req, res) => {
  const message = await messageService.sendMessage(
    req.user,
    req.validatedBody,
    req.validatedBody.body || req.validatedBody.messageText
  );
  res.status(201).json({
    success: true,
    message: 'Message sent successfully',
    data: messageService.publicMessage(message, req.user)
  });
}));

/**
 * GET /api/v1/messages/booking/:bookingId
 * The chat of one booking (customer <-> provider). Marks received messages as read.
 */
router.get('/booking/:bookingId', verifyToken, asyncHandler(async (req, res) => {
  if (!UUID.test(req.params.bookingId)) throw new ValidationError('bookingId must be a valid id');
  res.set('Cache-Control', 'no-store');
  const chat = await messageService.getBookingMessages(req.user, req.params.bookingId);
  res.status(200).json({ success: true, data: chat });
}));

router.post('/conversations', verifyToken, validateBody(conversationSchema), asyncHandler(async (req, res) => {
  const conversation = await messageService.getOrCreateConversation(req.user, req.validatedBody);
  res.status(200).json({ success: true, data: conversation });
}));

/**
 * GET /api/v1/messages/conversations
 * List all user's active conversations
 */
const listConversationsHandler = asyncHandler(async (req, res) => {
  const conversations = await messageService.listConversations(req.user, req.query.limit);
  res.status(200).json({
    success: true,
    data: { conversations }
  });
});

router.get('/', verifyToken, listConversationsHandler);
router.get('/conversations', verifyToken, listConversationsHandler);

/**
 * GET /api/v1/messages/:conversationId
 * Fetch message history for a conversation
 * Query params: page, limit
 */
router.get('/:conversationId', verifyToken, asyncHandler(async (req, res) => {
  if (!UUID.test(req.params.conversationId)) throw new ValidationError('conversationId must be a valid id');
  const result = await messageService.getConversation(
    req.user,
    req.params.conversationId,
    req.query.page,
    req.query.limit
  );
  res.status(200).json({
    success: true,
    data: result
  });
}));

/**
 * PUT /api/v1/messages/:id/read
 * Mark message as read
 */
router.put('/:id/read', verifyToken, asyncHandler(async (req, res) => {
  const message = await messageService.markAsRead(req.user, req.params.id);
  res.status(200).json({
    success: true,
    message: 'Message marked as read',
    data: message
  });
}));

/**
 * DELETE /api/v1/messages/:id
 * Delete a message
 */
router.delete('/:id', verifyToken, asyncHandler(async (req, res) => {
  await messageService.deleteOwnMessage(req.user, req.params.id);
  res.status(204).send();
}));

export default router;
