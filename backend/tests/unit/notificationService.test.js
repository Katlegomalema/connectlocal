import { jest } from '@jest/globals';

const notificationRepository = {
  createNotification: jest.fn(),
  markNotificationPushed: jest.fn()
};
const deviceTokenRepository = {
  registerDeviceToken: jest.fn(),
  listDeviceTokens: jest.fn(),
  deleteDeviceToken: jest.fn(),
  deleteDeviceTokensByToken: jest.fn()
};
const sendgrid = { sendEmail: jest.fn() };
const firebase = { sendMulticastNotification: jest.fn() };

jest.unstable_mockModule('../../src/repositories/notificationRepository.js', () => notificationRepository);
jest.unstable_mockModule('../../src/repositories/deviceTokenRepository.js', () => deviceTokenRepository);
jest.unstable_mockModule('../../src/integrations/sendgrid.js', () => sendgrid);
jest.unstable_mockModule('../../src/integrations/firebase.js', () => firebase);
const notificationService = await import('../../src/services/notificationService.js');

describe('Notification service', () => {
  beforeEach(() => jest.clearAllMocks());

  test('persists notifications using live database column names', async () => {
    notificationRepository.createNotification.mockResolvedValue({ id: 'notification-1', is_pushed: false });
    deviceTokenRepository.listDeviceTokens.mockResolvedValue([]);

    const result = await notificationService.sendInAppNotification('user-1', {
      type: 'booking',
      title: 'Booking received',
      body: 'A new booking is available',
      relatedEntityType: 'booking',
      relatedEntityId: 'booking-1'
    });

    expect(notificationRepository.createNotification).toHaveBeenCalledWith({
      user_id: 'user-1',
      notification_type: 'booking',
      title: 'Booking received',
      message: 'A new booking is available',
      related_entity_type: 'booking',
      related_entity_id: 'booking-1',
      is_read: false,
      is_pushed: false
    });
    expect(result.push).toEqual({ sent: 0, failed: 0, devices: 0 });
  });

  test('marks an in-app notification pushed after successful FCM delivery', async () => {
    notificationRepository.createNotification.mockResolvedValue({ id: 'notification-2', is_pushed: false });
    notificationRepository.markNotificationPushed.mockResolvedValue({ id: 'notification-2', is_pushed: true });
    deviceTokenRepository.listDeviceTokens.mockResolvedValue([{ token: 'valid-device-token' }]);
    firebase.sendMulticastNotification.mockResolvedValue({
      successCount: 1,
      failureCount: 0,
      responses: [{ success: true }]
    });

    const result = await notificationService.sendInAppNotification('user-1', {
      type: 'payment',
      title: 'Payment complete'
    });

    expect(notificationRepository.markNotificationPushed).toHaveBeenCalledWith('notification-2');
    expect(result.notification.is_pushed).toBe(true);
  });

  test('sends push notifications and removes invalid device tokens', async () => {
    deviceTokenRepository.listDeviceTokens.mockResolvedValue([
      { token: 'valid-token' },
      { token: 'expired-token' }
    ]);
    firebase.sendMulticastNotification.mockResolvedValue({
      successCount: 1,
      failureCount: 1,
      responses: [
        { success: true },
        { error: { code: 'messaging/registration-token-not-registered' } }
      ]
    });

    await expect(notificationService.sendPushNotification('user-1', {
      title: 'Booking update',
      body: 'Your booking changed',
      data: { bookingId: 12 }
    })).resolves.toEqual({ sent: 1, failed: 1, devices: 2 });
    expect(firebase.sendMulticastNotification).toHaveBeenCalledWith(
      ['valid-token', 'expired-token'],
      { title: 'Booking update', body: 'Your booking changed', data: { bookingId: '12' } }
    );
    expect(deviceTokenRepository.deleteDeviceTokensByToken).toHaveBeenCalledWith('user-1', ['expired-token']);
  });

  test('rejects unsupported device platforms', async () => {
    await expect(notificationService.registerDeviceToken(
      { id: 'user-1' },
      { token: 'a-valid-looking-device-token-123', platform: 'desktop' }
    )).rejects.toMatchObject({ statusCode: 400 });
    expect(deviceTokenRepository.registerDeviceToken).not.toHaveBeenCalled();
  });
});
