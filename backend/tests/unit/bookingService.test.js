import { jest } from '@jest/globals';

const repository = {
  getServiceById: jest.fn(),
  getProviderById: jest.fn(),
  hasBookingConflict: jest.fn(),
  createBooking: jest.fn(),
  getBookingById: jest.fn(),
  getProviderByUserId: jest.fn(),
  updateBooking: jest.fn(),
  listBookings: jest.fn()
};

jest.unstable_mockModule('../../src/repositories/bookingRepository.js', () => repository);
const bookingService = await import('../../src/services/bookingService.js');

describe('Booking service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('creates a pending booking using the service price and duration', async () => {
    repository.getServiceById.mockResolvedValue({
      id: 'service-1',
      provider_id: 'provider-1',
      price: '450.00',
      duration_minutes: 60,
      is_active: true
    });
    repository.getProviderById.mockResolvedValue({
      id: 'provider-1',
      user_id: 'provider-user-1',
      verification_status: 'approved'
    });
    repository.hasBookingConflict.mockResolvedValue(false);
    repository.createBooking.mockImplementation(async (booking) => ({ id: 'booking-1', ...booking }));

    const scheduledStart = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    const booking = await bookingService.createBooking(
      { id: 'customer-1', role: 'customer' },
      { providerId: 'provider-1', serviceId: 'service-1', scheduledStart, notes: 'Please call first' }
    );

    expect(booking.status).toBe('pending');
    expect(booking.total_price).toBe(450);
    expect(booking.customer_id).toBe('customer-1');
    expect(new Date(booking.scheduled_end).getTime() - new Date(booking.scheduled_start).getTime()).toBe(3600000);
    expect(repository.createBooking).toHaveBeenCalledTimes(1);
  });

  test('rejects a booking when the provider slot is already occupied', async () => {
    repository.getServiceById.mockResolvedValue({
      id: 'service-1',
      provider_id: 'provider-1',
      price: 450,
      duration_minutes: 60,
      is_active: true
    });
    repository.getProviderById.mockResolvedValue({ id: 'provider-1', verification_status: 'approved' });
    repository.hasBookingConflict.mockResolvedValue(true);

    await expect(bookingService.createBooking(
      { id: 'customer-1', role: 'customer' },
      {
        providerId: 'provider-1',
        serviceId: 'service-1',
        scheduledStart: new Date(Date.now() + 60 * 60 * 1000).toISOString()
      }
    )).rejects.toMatchObject({ statusCode: 409 });
    expect(repository.createBooking).not.toHaveBeenCalled();
  });

  test('rejects provider booking creation', async () => {
    await expect(bookingService.createBooking(
      { id: 'provider-user-1', role: 'provider' },
      { providerId: 'provider-1', serviceId: 'service-1', scheduledStart: new Date(Date.now() + 3600000).toISOString() }
    )).rejects.toMatchObject({ statusCode: 403 });
  });
});