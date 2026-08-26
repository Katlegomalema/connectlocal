/**
 * Firebase Integration
 * Push notifications via Firebase Cloud Messaging
 */

import admin from 'firebase-admin';
import logger from '../utils/logger.js';
import { ExternalServiceError } from '../utils/errors.js';

// Initialize Firebase (credentials from environment)
let initialized = false;

export const initializeFirebase = () => {
  if (initialized) return;

  try {
    if (!process.env.FIREBASE_PROJECT_ID) {
      logger.warn('Firebase not configured - push notifications disabled');
      return;
    }

    admin.initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL
    });

    initialized = true;
    logger.info('Firebase initialized');
  } catch (error) {
    logger.error('Firebase initialization error:', error);
  }
};

/**
 * Send push notification to user
 */
export const sendPushNotification = async (deviceToken, notification) => {
  try {
    if (!initialized) {
      logger.warn('Firebase not initialized - skipping push notification');
      return null;
    }

    const message = {
      notification: {
        title: notification.title,
        body: notification.body
      },
      data: notification.data || {},
      token: deviceToken
    };

    const response = await admin.messaging().send(message);
    logger.info('Push notification sent', { messageId: response });

    return response;
  } catch (error) {
    logger.error('Firebase push notification error:', error);
    throw new ExternalServiceError('Failed to send push notification', 'firebase');
  }
};

/**
 * Send notification to multiple devices
 */
export const sendMulticastNotification = async (deviceTokens, notification) => {
  try {
    if (!initialized) {
      logger.warn('Firebase not initialized - skipping multicast notification');
      return null;
    }

    const message = {
      notification: {
        title: notification.title,
        body: notification.body
      },
      data: notification.data || {},
      tokens: deviceTokens
    };

    const response = await admin.messaging().sendMulticast(message);
    logger.info('Multicast notification sent', { successCount: response.successCount });

    return response;
  } catch (error) {
    logger.error('Firebase multicast error:', error);
    throw new ExternalServiceError('Failed to send multicast notification', 'firebase');
  }
};

export default {
  initializeFirebase,
  sendPushNotification,
  sendMulticastNotification
};
