/**
 * Phase 6: booking notifications, booking chat, public reviews, admin lists, duplicate registration numbers.
 */
import { jest } from '@jest/globals';

const bookingRepository = { getBookingById: jest.fn() };
const notificationService = { sendInAppNotification: jest.fn() };
const messageRepository = {
  getBookingById: jest.fn(),
  getProviderByUserId: jest.fn(),
  listBookingMessages: jest.fn(),
  markBookingMessagesRead: jest.fn()
};
const reviewRepository = { listVisibleReviews: jest.fn() };
const adminRepository = {
  listAllBookings: jest.fn(),
  listAllPayouts: jest.fn(),
  listUsersWithBusiness: jest.fn(),
  countRows: jest.fn(async () => 0),
  getPaidRevenue: jest.fn(async () => 0),
  getAverageProviderRating: jest.fn(async () => 0),
  sumColumn: jest.fn(async () => 0)
};

jest.unstable_mockModule('../../src/repositories/bookingRepository.js', () => bookingRepository);
jest.unstable_mockModule('../../src/services/notificationService.js', () => notificationService);
jest.unstable_mockModule('../../src/repositories/messageRepository.js', () => messageRepository);
jest.unstable_mockModule('../../src/repositories/reviewRepository.js', () => reviewRepository);
jest.unstable_mockModule('../../src/repositories/adminRepository.js', () => adminRepository);
jest.unstable_mockModule('../../src/integrations/storage.js', () => ({ BUCKETS: {}, signedViewUrl: jest.fn() }));

const { notifyBookingEvent, money } = await import('../../src/services/bookingNotifier.js');
const messageService = await import('../../src/services/messageService.js');
const reviewService = await import('../../src/services/reviewService.js');
const adminService = await import('../../src/services/adminService.js');

const booking = {
  id: 'booking-1',
  customer_id: 'customer-user',
  provider_id: 'provider-1',
  scheduled_start: '2026-11-10T08:00:00Z',
  booking_fee_amount: '67.50',
  balance_amount: '382.50',
  service: { service_name: 'Window wash' },
  provider: { business_name: 'Shiny Co', user_id: 'provider-user' },
  customer: { full_name: 'Pat Doe' }
};

describe('booking notifications', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    bookingRepository.getBookingById.mockResolvedValue(booking);
  });

  test('money looks like the app: R450 / R67.50', () => {
    expect(money(450)).toBe('R450');
    expect(money('67.5')).toBe('R67.50');
  });

  test('a paid booking fee tells the PROVIDER about the new request (first name only)', async () => {
    await notifyBookingEvent('requested', 'booking-1');
    expect(notificationService.sendInAppNotification).toHaveBeenCalledTimes(1);
    const [userId, note] = notificationService.sendInAppNotification.mock.calls[0];
    expect(userId).toBe('provider-user');
    expect(note).toMatchObject({ type: 'booking', title: 'New house call request', relatedEntityId: 'booking-1' });
    expect(note.body).toContain('Pat booked Window wash');
    expect(note.body).not.toContain('Doe');
  });

  test('accepted / declined (with refund) go to the CUSTOMER', async () => {
    await notifyBookingEvent('accepted', 'booking-1');
    await notifyBookingEvent('declined', 'booking-1', { feeRefund: 'refunded' });
    const { calls } = notificationService.sendInAppNotification.mock;
    expect(calls.map(([userId]) => userId)).toEqual(['customer-user', 'customer-user']);
    expect(calls[1][1].body).toContain('R67.50 booking fee was refunded');
  });

  test('a paid balance tells both sides', async () => {
    await notifyBookingEvent('balancePaid', 'booking-1', { method: 'cash' });
    const { calls } = notificationService.sendInAppNotification.mock;
    expect(calls.map(([userId]) => userId)).toEqual(['provider-user', 'customer-user']);
    expect(calls[0][1].body).toContain('R382.50 balance in cash');
  });

  test('a failure is logged, never thrown (the booking action still succeeds)', async () => {
    notificationService.sendInAppNotification.mockRejectedValue(new Error('db down'));
    await expect(notifyBookingEvent('completed', 'booking-1')).resolves.toBeUndefined();
    bookingRepository.getBookingById.mockRejectedValue(new Error('not found'));
    await expect(notifyBookingEvent('accepted', 'booking-1')).resolves.toBeUndefined();
  });
});

describe('booking chat', () => {
  const customer = { id: 'customer-user', role: 'customer' };
  const provider = { id: 'provider-user', role: 'provider' };
  const rows = [
    {
      id: 'm1', conversation_id: 'c1', booking_id: 'booking-1', sender_id: 'customer-user', receiver_id: 'provider-user', message_text: 'Hi', is_read: true, created_at: '2026-11-05T10:00:00Z'
    },
    {
      id: 'm2', conversation_id: 'c1', booking_id: 'booking-1', sender_id: 'provider-user', receiver_id: 'customer-user', message_text: 'On my way', is_read: false, created_at: '2026-11-05T10:01:00Z'
    }
  ];

  beforeEach(() => {
    jest.clearAllMocks();
    messageRepository.getBookingById.mockResolvedValue({ id: 'booking-1', customer_id: 'customer-user', provider_id: 'provider-1' });
    messageRepository.listBookingMessages.mockResolvedValue(rows);
  });

  test('the customer sees the chat with "mine" set, and unread messages are marked read', async () => {
    const chat = await messageService.getBookingMessages(customer, 'booking-1');
    expect(chat.conversationId).toBe('c1');
    expect(chat.messages.map((m) => [m.text, m.mine])).toEqual([['Hi', true], ['On my way', false]]);
    expect(chat.messages[0]).not.toHaveProperty('sender_id');
    expect(messageRepository.markBookingMessagesRead).toHaveBeenCalledWith('booking-1', 'customer-user');
  });

  test('the provider who owns the booked business can read it', async () => {
    messageRepository.getProviderByUserId.mockResolvedValue({ id: 'provider-1' });
    const chat = await messageService.getBookingMessages(provider, 'booking-1');
    expect(chat.messages[1].mine).toBe(true);
  });

  test('anyone else is refused', async () => {
    messageRepository.getProviderByUserId.mockResolvedValue({ id: 'provider-2' });
    await expect(messageService.getBookingMessages({ id: 'x', role: 'provider' }, 'booking-1')).rejects.toThrow('not a party');
    await expect(messageService.getBookingMessages({ id: 'y', role: 'customer' }, 'booking-1')).rejects.toThrow('not a party');
    expect(messageRepository.listBookingMessages).not.toHaveBeenCalled();
  });
});

describe('public reviews', () => {
  test('show the first name and service, never the customer id or surname', async () => {
    reviewRepository.listVisibleReviews.mockResolvedValue({
      reviews: [{
        id: 'r1', booking_id: 'booking-1', customer_id: 'customer-user', provider_id: 'provider-1', rating: 5, review_text: 'Great', created_at: 'now', customer: { full_name: 'Pat Doe' }, booking: { service: { service_name: 'Window wash' } }
      }],
      averageRating: 5,
      totalReviews: 1,
      page: 1,
      pages: 1
    });
    const result = await reviewService.getProviderReviews('provider-1');
    expect(result.reviews[0]).toEqual(expect.objectContaining({
      rating: 5, comment: 'Great', customerFirstName: 'Pat', serviceName: 'Window wash'
    }));
    expect(JSON.stringify(result)).not.toContain('Doe');
    expect(result.reviews[0]).not.toHaveProperty('customer_id');
  });
});

describe('admin lists', () => {
  const admin = { id: 'admin-1', role: 'admin' };

  test('only admins', async () => {
    await expect(adminService.listBookings({ id: 'u', role: 'customer' })).rejects.toThrow('Administrator');
    await expect(adminService.listPayouts({ id: 'u', role: 'provider' })).rejects.toThrow('Administrator');
  });

  test('bookings never include the PIN hash', async () => {
    adminRepository.listAllBookings.mockResolvedValue({
      rows: [{ id: 'b1', arrival_pin_hash: 'secret', service_location: null }], total: 1, page: 1, pages: 1
    });
    const result = await adminService.listBookings(admin, {});
    expect(result.bookings[0]).not.toHaveProperty('arrival_pin_hash');
  });

  test('payouts show only the last 4 digits of the bank account', async () => {
    adminRepository.listAllPayouts.mockResolvedValue({
      rows: [{
        id: 'p1',
        booking_id: 'b1',
        provider_id: 'provider-1',
        gross_amount: '450.00',
        commission_rate: '0.1000',
        commission_amount: '45.00',
        cash_collected_amount: '382.50',
        payout_amount: '22.50',
        status: 'paid',
        provider: {
          business_name: 'Shiny Co',
          bank: [{
            bank_name: 'FNB', account_type: 'Savings', account_holder_name: 'Pat Doe', branch_code: '250655', account_last4: '5678'
          }]
        }
      }],
      total: 1,
      page: 1,
      pages: 1
    });
    const { payouts } = await adminService.listPayouts(admin, {});
    expect(payouts[0]).toMatchObject({ payoutAmount: 22.5, businessName: 'Shiny Co', bank: { accountLast4: '5678' } });
    expect(JSON.stringify(payouts)).not.toMatch(/account_number|encrypted/);
  });

  test('users: status from is_active / deleted_at, business attached', async () => {
    adminRepository.listUsersWithBusiness.mockResolvedValue({
      rows: [
        {
          id: 'u1', full_name: 'Pat', email: 'p@x', role: 'provider', is_active: false, deleted_at: null, business: { id: 'pr1', business_name: 'Shiny Co', verification_status: 'verified' }
        },
        {
          id: 'u2', full_name: 'Sam', email: 's@x', role: 'customer', is_active: true, deleted_at: null, business: null
        }
      ],
      total: 2,
      page: 1,
      pages: 1
    });
    const { users } = await adminService.listUsers(admin, {});
    expect(users.map((u) => u.status)).toEqual(['suspended', 'active']);
    expect(users[0].business).toEqual({ id: 'pr1', name: 'Shiny Co', verificationStatus: 'verified' });
  });

  test('analytics report the fixed 10% commission', async () => {
    const stats = await adminService.getAnalytics(admin);
    expect(stats.commissionRate).toBe(0.1);
  });
});
