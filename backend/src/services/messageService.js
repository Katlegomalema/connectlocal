/**
 * Message Service
 * Persistent conversation messaging
 */

import * as messageRepository from '../repositories/messageRepository.js';
import { AuthorizationError, ConflictError, ValidationError } from '../utils/errors.js';
import { randomUUID } from 'node:crypto';

const requireParticipant = (actor, conversation) => {
  if (actor.id !== conversation.user_a_id && actor.id !== conversation.user_b_id) {
    throw new AuthorizationError('You are not a participant in this conversation');
  }
};

const parsePagination = (pageValue, limitValue, defaultLimit = 50) => {
  const page = Number.parseInt(pageValue, 10) || 1;
  const limit = Number.parseInt(limitValue, 10) || defaultLimit;
  if (page < 1 || limit < 1 || limit > 100) {
    throw new ValidationError('page must be positive and limit must be between 1 and 100');
  }
  return { page, limit };
};

export const getOrCreateConversation = async (actor, { otherUserId, bookingId }) => {
  if (!actor || !['customer', 'provider'].includes(actor.role)) {
    throw new AuthorizationError('Only customers and providers can start conversations');
  }

  let participantId = otherUserId;
  if (bookingId) {
    const booking = await messageRepository.getBookingById(bookingId);
    if (booking.customer_id === actor.id) {
      const provider = await messageRepository.getProviderById(booking.provider_id);
      participantId = provider.user_id;
    } else {
      const provider = await messageRepository.getProviderByUserId(actor.id);
      if (!provider || provider.id !== booking.provider_id) {
        throw new AuthorizationError('You are not a party to this booking');
      }
      participantId = booking.customer_id;
    }
    if (otherUserId && otherUserId !== participantId) {
      throw new AuthorizationError('The requested user is not a party to this booking');
    }
  }

  if (!participantId || participantId === actor.id) {
    throw new ValidationError('otherUserId must identify another user');
  }

  const otherUser = await messageRepository.getUserById(participantId);
  if (!['customer', 'provider'].includes(otherUser.role) || otherUser.role === actor.role) {
    throw new ValidationError('Conversations must be between a customer and a provider');
  }

  const existing = await messageRepository.findConversationBetween(actor.id, participantId, bookingId);
  const [userAId, userBId] = [actor.id, participantId].sort();
  return {
    id: existing?.conversation_id || randomUUID(),
    user_a_id: userAId,
    user_b_id: userBId,
    participant_id: participantId,
    booking_id: bookingId || null
  };
};

export const listConversations = async (actor, limitValue) => {
  if (!actor?.id) throw new AuthorizationError('Authentication required');
  const { limit } = parsePagination(1, limitValue, 50);
  return messageRepository.listConversations(actor.id, limit);
};

export const sendMessage = async (actor, { conversationId, receiverId, bookingId }, body) => {
  const text = typeof body === 'string' ? body.trim() : '';
  if (!text || text.length > 2000) {
    throw new ValidationError('Message body must contain between 1 and 2000 characters');
  }
  let conversation;
  if (conversationId && receiverId) {
    conversation = await getOrCreateConversation(actor, { otherUserId: receiverId, bookingId });
    conversation.id = conversationId;
  } else if (conversationId) {
    const existing = await messageRepository.getConversationById(conversationId);
    requireParticipant(actor, existing);
    conversation = {
      id: conversationId,
      booking_id: existing.booking_id,
      participant_id: actor.id === existing.user_a_id ? existing.user_b_id : existing.user_a_id
    };
  } else {
    conversation = await getOrCreateConversation(actor, { otherUserId: receiverId, bookingId });
  }

  return messageRepository.createMessage({
    conversation_id: conversation.id,
    booking_id: conversation.booking_id,
    sender_id: actor.id,
    receiver_id: conversation.participant_id,
    message_text: text,
    is_read: false
  });
};

export const getConversation = async (actor, conversationId, pageValue, limitValue) => {
  const conversation = await messageRepository.getConversationById(conversationId);
  requireParticipant(actor, conversation);
  const { page, limit } = parsePagination(pageValue, limitValue);
  return messageRepository.listMessages(conversationId, page, limit);
};

export const markAsRead = async (actor, messageId) => {
  const message = await messageRepository.getMessageById(messageId);
  const conversation = await messageRepository.getConversationById(message.conversation_id);
  requireParticipant(actor, conversation);
  if (message.receiver_id !== actor.id) {
    throw new AuthorizationError('Only the recipient can mark a message as read');
  }
  if (message.is_read) return message;
  return messageRepository.updateMessageStatus(messageId);
};

export const deleteOwnMessage = async (actor, messageId) => {
  const message = await messageRepository.getMessageById(messageId);
  if (message.sender_id !== actor.id) {
    throw new AuthorizationError('You can only delete messages you sent');
  }
  return messageRepository.deleteMessage(messageId, actor.id);
};

export default {
  getOrCreateConversation,
  listConversations,
  sendMessage,
  getConversation,
  markAsRead,
  deleteOwnMessage
};
