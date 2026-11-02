/**
 * Notification Service
 * In-app and email notifications
 */

import * as notificationRepository from '../repositories/notificationRepository.js';
import * as sendgrid from '../integrations/sendgrid.js';
import { AppError, ValidationError } from '../utils/errors.js';

const parsePagination = (pageValue, limitValue) => {
  const page = Number.parseInt(pageValue, 10) || 1;
  const limit = Number.parseInt(limitValue, 10) || 20;
  if (!Number.isInteger(page) || !Number.isInteger(limit) || page < 1 || limit < 1 || limit > 100) {
    throw new ValidationError('page must be positive and limit must be between 1 and 100');
  }
  return { page, limit };
};

export const sendInAppNotification = async (userId, notification) => {
  if (!userId || !notification?.type || !notification?.title) {
    throw new ValidationError('userId, type, and title are required');
  }
  return notificationRepository.createNotification({
    user_id: userId,
    type: notification.type,
    title: notification.title,
    body: notification.body || null,
    is_read: false,
    metadata: notification.metadata || {}
  });
};

export const listInAppNotifications = async (actor, filters = {}) => {
  if (!actor?.id) throw new AppError('Authentication required', 401, 'AUTHENTICATION_ERROR');
  const { page, limit } = parsePagination(filters.page, filters.limit);
  const unreadOnly = filters.unreadOnly === true || filters.unreadOnly === 'true';
  return notificationRepository.listNotifications(actor.id, { unreadOnly, page, limit });
};

export const markAsRead = async (actor, notificationId) => notificationRepository.markNotificationRead(actor.id, notificationId);

export const markAllAsRead = async (actor) => notificationRepository.markAllNotificationsRead(actor.id);

export const deleteNotification = async (actor, notificationId) => notificationRepository.deleteNotification(actor.id, notificationId);

export const sendPushNotification = async () => {
  throw new AppError('Push delivery is unavailable until device tokens are stored in the database', 501, 'NOT_IMPLEMENTED');
};

export const sendEmailNotification = async (email, template, data = {}) => {
  const subject = data.subject || template;
  const html = data.html || data.body || '';
  const text = data.text || data.body || '';
  const result = await sendgrid.sendEmail(email, subject, html, text);
  return { sent: Boolean(result), email };
};

export default {
  sendPushNotification,
  sendInAppNotification,
  sendEmailNotification,
  listInAppNotifications,
  markAsRead,
  markAllAsRead,
  deleteNotification
};
