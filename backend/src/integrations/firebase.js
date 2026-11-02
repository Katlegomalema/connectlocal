/**
 * Firebase Integration
 * Push notifications via Firebase Cloud Messaging
 */

import admin from 'firebase-admin';
import logger from '../utils/logger.js';
import { ExternalServiceError } from '../utils/errors.js';

let initialized = false;

export const initializeFirebase = () => {
  if (initialized) return;

  try {
    if (!process.env.FIREBASE_PROJECT_ID || !process.env.FIREBASE_CLIENT_EMAIL || !process.env.FIREBASE_PRIVATE_KEY) {
      logger.warn('Firebase not configured - push notifications disabled');
      return;
    }

    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
      })
    });

    initialized = true;
    logger.info('Firebase initialized');
  } catch (error) {
    logger.error('Firebase initialization error:', error);
    throw new ExternalServiceError('Failed to initialize Firebase', 'firebase');
  }
};

/**
 * Send push notification to user
 */
export const sendPushNotification = async (deviceToken, notification) => {
  try {
    initializeFirebase();

    if (!initialized || !deviceToken) {
      logger.warn('Firebase not initialized or token missing - skipping push notification');
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
    logger.error('Firebase push notification error:', error?.message || error);
    throw new ExternalServiceError('Failed to send push notification', 'firebase');
  }
};

/**
 * Send notification to multiple devices
 */
export const sendMulticastNotification = async (deviceTokens, notification) => {
  try {
    initializeFirebase();

    if (!initialized || !Array.isArray(deviceTokens) || deviceTokens.length === 0) {
      logger.warn('Firebase not initialized or tokens missing - skipping multicast notification');
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

    const response = await admin.messaging().sendEachForMulticast(message);
    logger.info('Multicast notification sent', { successCount: response.successCount });

    return response;
  } catch (error) {
    logger.error('Firebase multicast error:', error?.message || error);
    throw new ExternalServiceError('Failed to send multicast notification', 'firebase');
  }
};

export default {
  initializeFirebase,
  sendPushNotification,
  sendMulticastNotification
};
