/**
 * Notification Repository
 * Database operations for in-app notifications
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { NotFoundError } from '../utils/errors.js';

export const createNotification = async (notification) => {
  const { data, error } = await supabase
    .from('notifications')
    .insert(notification)
    .select('*')
    .single();

  if (error) throw error;
  return data;
};

export const markNotificationPushed = async (notificationId) => {
  const { data, error } = await supabase
    .from('notifications')
    .update({ is_pushed: true })
    .eq('id', notificationId)
    .select('*')
    .single();

  if (error) throw error;
  return data;
};

export const listNotifications = async (userId, { unreadOnly, page, limit }) => {
  let query = supabase
    .from('notifications')
    .select('*', { count: 'exact' })
    .eq('user_id', userId)
    .order('created_at', { ascending: false });
  if (unreadOnly) query = query.eq('is_read', false);

  const offset = (page - 1) * limit;
  const { data, error, count } = await query.range(offset, offset + limit - 1);
  if (error) throw error;
  return {
    notifications: data || [],
    total: count || 0,
    page,
    pages: Math.ceil((count || 0) / limit)
  };
};

export const markNotificationRead = async (userId, notificationId) => {
  const { data, error } = await supabase
    .from('notifications')
    .update({ is_read: true })
    .eq('id', notificationId)
    .eq('user_id', userId)
    .select('*')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Notification not found');
  return data;
};

export const markAllNotificationsRead = async (userId) => {
  const { data, error } = await supabase
    .from('notifications')
    .update({ is_read: true })
    .eq('user_id', userId)
    .eq('is_read', false)
    .select('id');

  if (error) throw error;
  return { updated: data?.length || 0 };
};

export const deleteNotification = async (userId, notificationId) => {
  const { data, error } = await supabase
    .from('notifications')
    .delete()
    .eq('id', notificationId)
    .eq('user_id', userId)
    .select('id')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Notification not found');
  return { success: true };
};

export default {
  createNotification,
  markNotificationPushed,
  listNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  deleteNotification
};
