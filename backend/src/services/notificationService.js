/**
 * Notification Service
 * In-app and email notifications
 */

import * as notificationRepository from '../repositories/notificationRepository.js';
import * as deviceTokenRepository from '../repositories/deviceTokenRepository.js';
import * as sendgrid from '../integrations/sendgrid.js';
import * as firebase from '../integrations/firebase.js';
import { AppError, ValidationError } from '../utils/errors.js';

const notificationTypes = ['booking', 'payment', 'message', 'review', 'system'];
const devicePlatforms = ['android', 'ios', 'web'];

const getNotificationData = (notification) => {
  const data = notification.data ?? {};
  if (typeof data !== 'object' || Array.isArray(data)) {
    throw new ValidationError('Notification data must be an object');
  }
  return data;
};

const parsePagination = (pageValue, limitValue) => {
  const page = Number.parseInt(pageValue, 10) || 1;
  const limit = Number.parseInt(limitValue, 10) || 20;
  if (!Number.isInteger(page) || !Number.isInteger(limit) || page < 1 || limit < 1 || limit > 100) {
    throw new ValidationError('page must be positive and limit must be between 1 and 100');
  }
  return { page, limit };
};

export const sendPushNotification = async (userId, notification) => {
  if (!userId || typeof notification?.title !== 'string' || !notification.title.trim()) {
    throw new ValidationError('userId and notification title are required');
  }
  if (notification.body !== undefined && typeof notification.body !== 'string') {
    throw new ValidationError('Notification body must be a string');
  }
  const notificationData = getNotificationData(notification);
  const devices = await deviceTokenRepository.listDeviceTokens(userId);
  if (devices.length === 0) return { sent: 0, failed: 0, devices: 0 };

  const data = Object.fromEntries(
    Object.entries(notificationData).map(([key, value]) => [key, String(value)])
  );
  const response = await firebase.sendMulticastNotification(
    devices.map((device) => device.token),
    {
      title: notification.title.trim(),
      body: notification.body || '',
      data
    }
  );
  const invalidTokens = response.responses
    .map((result, index) => ({
      token: devices[index].token,
      code: result.error?.code
    }))
    .filter(({ code }) => [
      'messaging/invalid-registration-token',
      'messaging/registration-token-not-registered'
    ].includes(code))
    .map(({ token }) => token);
  await deviceTokenRepository.deleteDeviceTokensByToken(userId, invalidTokens);

  return {
    sent: response.successCount,
    failed: response.failureCount,
    devices: devices.length
  };
};

export const sendInAppNotification = async (userId, notification) => {
  if (
    !userId
    || !notification?.type
    || typeof notification.title !== 'string'
    || !notification.title.trim()
  ) {
    throw new ValidationError('userId, type, and title are required');
  }
  if (!notificationTypes.includes(notification.type)) {
    throw new ValidationError('Invalid notification type');
  }
  if (notification.body !== undefined && typeof notification.body !== 'string') {
    throw new ValidationError('Notification body must be a string');
  }
  getNotificationData(notification);
  const savedNotification = await notificationRepository.createNotification({
    user_id: userId,
    notification_type: notification.type,
    title: notification.title.trim(),
    message: notification.body || null,
    related_entity_type: notification.relatedEntityType || null,
    related_entity_id: notification.relatedEntityId || null,
    is_read: false,
    is_pushed: false
  });
  const push = await sendPushNotification(userId, notification);
  const deliveredNotification = push.sent > 0
    ? await notificationRepository.markNotificationPushed(savedNotification.id)
    : savedNotification;
  return { notification: deliveredNotification, push };
};

export const listInAppNotifications = async (actor, filters = {}) => {
  if (!actor?.id) throw new AppError('Authentication required', 401, 'AUTHENTICATION_ERROR');
  const { page, limit } = parsePagination(filters.page, filters.limit);
  const unreadOnly = filters.unreadOnly === true || filters.unreadOnly === 'true';
  return notificationRepository.listNotifications(actor.id, { unreadOnly, page, limit });
};

export const markAsRead = async (actor, notificationId) => (
  notificationRepository.markNotificationRead(actor.id, notificationId)
);

export const markAllAsRead = async (actor) => (
  notificationRepository.markAllNotificationsRead(actor.id)
);

export const deleteNotification = async (actor, notificationId) => (
  notificationRepository.deleteNotification(actor.id, notificationId)
);

export const registerDeviceToken = async (actor, { token, platform } = {}) => {
  if (!actor?.id) throw new AppError('Authentication required', 401, 'AUTHENTICATION_ERROR');
  const normalizedToken = typeof token === 'string' ? token.trim() : '';
  if (normalizedToken.length < 20 || normalizedToken.length > 4096) {
    throw new ValidationError('token must contain between 20 and 4096 characters');
  }
  if (!devicePlatforms.includes(platform)) {
    throw new ValidationError('platform must be android, ios, or web');
  }
  return deviceTokenRepository.registerDeviceToken(actor.id, normalizedToken, platform);
};

export const removeDeviceToken = async (actor, deviceTokenId) => {
  if (!actor?.id) throw new AppError('Authentication required', 401, 'AUTHENTICATION_ERROR');
  return deviceTokenRepository.deleteDeviceToken(actor.id, deviceTokenId);
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
  registerDeviceToken,
  removeDeviceToken,
  sendEmailNotification,
  listInAppNotifications,
  markAsRead,
  markAllAsRead,
  deleteNotification
};
