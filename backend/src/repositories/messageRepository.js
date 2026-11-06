/**
 * Message Repository
 * Database operations against the live messages table
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { NotFoundError } from '../utils/errors.js';

export const getUserById = async (userId) => {
  const { data, error } = await supabase
    .from('users')
    .select('id, role, is_active, deleted_at')
    .eq('id', userId)
    .maybeSingle();
  if (error) throw error;
  if (!data || !data.is_active || data.deleted_at) throw new NotFoundError('User not found');
  return data;
};

export const getProviderByUserId = async (userId) => {
  const { data, error } = await supabase
    .from('providers')
    .select('id, user_id')
    .eq('user_id', userId)
    .maybeSingle();
  if (error) throw error;
  return data;
};

export const getProviderById = async (providerId) => {
  const { data, error } = await supabase
    .from('providers')
    .select('id, user_id')
    .eq('id', providerId)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new NotFoundError('Provider not found');
  return data;
};

export const getBookingById = async (bookingId) => {
  const { data, error } = await supabase
    .from('bookings')
    .select('id, customer_id, provider_id')
    .eq('id', bookingId)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new NotFoundError('Booking not found');
  return data;
};

export const getConversationById = async (conversationId) => {
  const { data, error } = await supabase
    .from('messages')
    .select('conversation_id, booking_id, sender_id, receiver_id')
    .eq('conversation_id', conversationId)
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new NotFoundError('Conversation not found');
  return {
    id: data.conversation_id,
    booking_id: data.booking_id,
    user_a_id: [data.sender_id, data.receiver_id].sort()[0],
    user_b_id: [data.sender_id, data.receiver_id].sort()[1]
  };
};

export const findConversation = async (conversationId, userId) => {
  const { data, error } = await supabase
    .from('messages')
    .select('conversation_id, booking_id, sender_id, receiver_id')
    .eq('conversation_id', conversationId)
    .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`)
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data;
};

export const findConversationBetween = async (userAId, userBId, bookingId) => {
  let query = supabase
    .from('messages')
    .select('conversation_id, booking_id, sender_id, receiver_id')
    .or(`and(sender_id.eq.${userAId},receiver_id.eq.${userBId}),and(sender_id.eq.${userBId},receiver_id.eq.${userAId})`);

  query = bookingId ? query.eq('booking_id', bookingId) : query.is('booking_id', null);
  const { data, error } = await query.order('created_at', { ascending: false }).limit(1).maybeSingle();
  if (error) throw error;
  return data;
};

export const listConversations = async (userId, limit = 50) => {
  const { data, error } = await supabase
    .from('messages')
    .select('conversation_id, booking_id, sender_id, receiver_id, message_text, created_at, is_read')
    .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`)
    .order('created_at', { ascending: false })
    .limit(1000);
  if (error) throw error;

  const latest = new Map();
  for (const message of data || []) {
    if (!latest.has(message.conversation_id)) {
      latest.set(message.conversation_id, {
        id: message.conversation_id,
        booking_id: message.booking_id,
        participant_id: message.sender_id === userId ? message.receiver_id : message.sender_id,
        last_message: message.message_text,
        last_message_at: message.created_at,
        last_message_mine: message.sender_id === userId,
        is_read: message.is_read,
        unread_count: 0
      });
    }
    if (message.receiver_id === userId && !message.is_read) latest.get(message.conversation_id).unread_count += 1;
  }
  return [...latest.values()].slice(0, limit);
};

/** All messages of a booking's chat that [userId] sent or received, oldest first. */
export const listBookingMessages = async (bookingId, userId, limit = 200) => {
  const { data, error } = await supabase
    .from('messages')
    .select('id, conversation_id, booking_id, sender_id, receiver_id, message_text, is_read, created_at')
    .eq('booking_id', bookingId)
    .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`)
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data || []).reverse();
};

/** Marks everything [userId] received in this booking's chat as read. */
export const markBookingMessagesRead = async (bookingId, userId) => {
  const { error } = await supabase
    .from('messages')
    .update({ is_read: true })
    .eq('booking_id', bookingId)
    .eq('receiver_id', userId)
    .eq('is_read', false);
  if (error) throw error;
};

export const createMessage = async (message) => {
  const { data, error } = await supabase
    .from('messages')
    .insert(message)
    .select('*')
    .single();
  if (error) throw error;
  return data;
};

export const listMessages = async (conversationId, page, limit) => {
  const offset = (page - 1) * limit;
  const { data, error, count } = await supabase
    .from('messages')
    .select('*', { count: 'exact' })
    .eq('conversation_id', conversationId)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);
  if (error) throw error;
  return {
    messages: (data || []).reverse(),
    total: count || 0,
    page,
    pages: Math.ceil((count || 0) / limit)
  };
};

export const getMessageById = async (messageId) => {
  const { data, error } = await supabase
    .from('messages')
    .select('*')
    .eq('id', messageId)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new NotFoundError('Message not found');
  return data;
};

export const updateMessageStatus = async (messageId) => {
  const { data, error } = await supabase
    .from('messages')
    .update({ is_read: true })
    .eq('id', messageId)
    .select('*')
    .single();
  if (error) throw error;
  return data;
};

export const deleteMessage = async (messageId, senderId) => {
  const { data, error } = await supabase
    .from('messages')
    .delete()
    .eq('id', messageId)
    .eq('sender_id', senderId)
    .select('id')
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new NotFoundError('Message not found');
  return data;
};

export default {
  getUserById,
  getProviderByUserId,
  getProviderById,
  getBookingById,
  getConversationById,
  findConversation,
  findConversationBetween,
  listConversations,
  listBookingMessages,
  markBookingMessagesRead,
  createMessage,
  listMessages,
  getMessageById,
  updateMessageStatus,
  deleteMessage
};
