import { jest } from '@jest/globals';

process.env.CODE_HASH_SECRET = process.env.CODE_HASH_SECRET || 'test-only-secret-test-only-secret-test-only-secret';

const repository = {
  getServiceById: jest.fn(),
  getProviderById: jest.fn(),
  getPackageById: jest.fn(),
  getCustomerById: jest.fn(),
  hasBookingConflict: jest.fn(),
  getProviderAvailability: jest.fn(),
  findPendingDuplicate: jest.fn(),
  createBooking: jest.fn(),
  getBookingById: jest.fn(),
  getProviderByUserId: jest.fn(),
  updateBooking: jest.fn(),
  listBookings: jest.fn()
};
const paymentService = {
  refundBookingFee: jest.fn(),
  recordCashBalance: jest.fn()
};

jest.unstable_mockModule('../../src/repositories/bookingRepository.js', () => repository);
const payoutService = { hasPayoutDetails: jest.fn() };
jest.unstable_mockModule('../../src/services/paymentService.js', () => paymentService);
jest.unstable_mockModule('../../src/services/payoutService.js', () => payoutService);
jest.unstable_mockModule('../../src/services/bookingNotifier.js', () => ({ notifyBookingEvent: jest.fn(async () => {}) }));
const bookingService = await import('../../src/services/bookingService.js');
const { deriveArrivalPin, hashArrivalPin } = await import('../../src/utils/secureCodes.js');

const customer = { id: 'customer-1', role: 'customer' };
const providerUser = { id: 'provider-user-1', role: 'provider' };
/** Tomorrow 10:00 South African time (08:00 UTC): inside the working hours the tests set. */
const inOneDay = () => {
  const d = new Date(Date.now() + 86400000);
  d.setUTCHours(8, 0, 0, 0);
  return d.toISOString();
};
/** Open every day 06:00-20:00 (provider_availability rows, 0 = Sunday). */
const allWeek = [0, 1, 2, 3, 4, 5, 6].map((day) => ({ day_of_week: day, start_time: '06:00:00', end_time: '20:00:00' }));
const verifiedProvider = {
  id: 'provider-1', user_id: 'provider-user-1', verification_status: 'verified', is_active: true
};

const givenService = (overrides = {}) => repository.getServiceById.mockResolvedValue({
  id: 'service-1',
  provider_id: 'provider-1',
  base_price: '450.00',
  duration_minutes: 60,
  active: true,
  pricing_type: 'fixed',
  ...overrides
});

describe('Booking service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    repository.getCustomerById.mockResolvedValue({ id: 'customer-1', email_verified: true, phone_verified: true });
    repository.getProviderById.mockResolvedValue(verifiedProvider);
    repository.getProviderByUserId.mockResolvedValue(verifiedProvider);
    repository.hasBookingConflict.mockResolvedValue(false);
    repository.getProviderAvailability.mockResolvedValue(allWeek);
    repository.findPendingDuplicate.mockResolvedValue(null);
    repository.createBooking.mockImplementation(async (booking) => ({ id: 'booking-1', ...booking }));
    repository.updateBooking.mockImplementation(async (id, statuses, updates) => ({ id, ...updates }));
    payoutService.hasPayoutDetails.mockResolvedValue(true);
  });

  // ---------------- create ----------------
  test('fixed price: total = base price, fee = 15%, balance left to the database', async () => {
    givenService();
    const booking = await bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay(), notes: 'Please call first'
    });

    expect(booking).toMatchObject({
      status: 'pending',
      customer_id: 'customer-1',
      pricing_type_at_booking: 'fixed',
      quantity: 1,
      total_amount: 450,
      booking_fee_rate: 0.15,
      booking_fee_amount: 67.5,
      booking_fee_status: 'pending'
    });
    expect(new Date(booking.scheduled_end) - new Date(booking.scheduled_start)).toBe(3600000);
  });

  test('hourly price: hours x rate, and the slot lasts that many hours', async () => {
    givenService({ pricing_type: 'hourly', base_price: '200.00' });
    const booking = await bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay(), hours: 3
    });
    expect(booking).toMatchObject({ total_amount: 600, quantity: 3, booking_fee_amount: 90 });
    expect(new Date(booking.scheduled_end) - new Date(booking.scheduled_start)).toBe(3 * 3600000);
  });

  test('package price: uses the package price and keeps a snapshot of its name', async () => {
    givenService({ pricing_type: 'package' });
    repository.getPackageById.mockResolvedValue({
      id: 'pkg-1', service_id: 'service-1', name: 'Full house', price: '1200.00', duration_minutes: 180, is_active: true
    });
    const booking = await bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay(), packageId: 'pkg-1'
    });
    expect(booking).toMatchObject({
      total_amount: 1200, booking_fee_amount: 180, package_id: 'pkg-1', package_name_at_booking: 'Full house'
    });
  });

  test('package from another service is rejected', async () => {
    givenService({ pricing_type: 'package' });
    repository.getPackageById.mockResolvedValue({
      id: 'pkg-9', service_id: 'other-service', name: 'X', price: 1, is_active: true
    });
    await expect(bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay(), packageId: 'pkg-9'
    })).rejects.toThrow('Package not found');
  });

  test('customer without a verified phone cannot book', async () => {
    repository.getCustomerById.mockResolvedValue({ id: 'customer-1', email_verified: true, phone_verified: false });
    givenService();
    await expect(bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    })).rejects.toThrow('Verify your email address and phone number');
    expect(repository.createBooking).not.toHaveBeenCalled();
  });

  test('rejects a booking when the provider slot is already occupied', async () => {
    givenService();
    repository.hasBookingConflict.mockResolvedValue(true);
    await expect(bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    })).rejects.toThrow('no longer available');
    expect(repository.createBooking).not.toHaveBeenCalled();
  });

  test('the same request sent twice (retry / double tap) returns the first booking, not a second one', async () => {
    givenService();
    repository.findPendingDuplicate.mockResolvedValue({ id: 'booking-1', status: 'pending', customer_id: 'customer-1' });
    const booking = await bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    });
    expect(booking).toMatchObject({ id: 'booking-1', reused: true });
    expect(repository.createBooking).not.toHaveBeenCalled();
    expect(repository.findPendingDuplicate).toHaveBeenCalledWith(expect.objectContaining({
      customerId: 'customer-1', providerId: 'provider-1', serviceId: 'service-1'
    }));
  });

  test('the slot check keeps 30 minutes free before and after the booking', async () => {
    givenService();
    await bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    });
    const [, from, to] = repository.hasBookingConflict.mock.calls[0];
    const start = new Date(inOneDay()).getTime();
    expect(new Date(from).getTime()).toBe(start - 30 * 60000);
    expect(new Date(to).getTime()).toBe(start + 60 * 60000 + 30 * 60000); // 1-hour slot + gap
  });

  test('a time outside the working hours is refused', async () => {
    givenService();
    // Open 09:00-10:00 every day: a 10:00-11:00 booking (SAST) never fits.
    repository.getProviderAvailability.mockResolvedValue([0, 1, 2, 3, 4, 5, 6]
      .map((day) => ({ day_of_week: day, start_time: '09:00:00', end_time: '10:00:00' })));
    await expect(bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    })).rejects.toThrow('outside the provider');
    expect(repository.createBooking).not.toHaveBeenCalled();
  });

  test('without saved hours the standard hours apply (Mon-Fri 8-17, Sat 9-13, Sunday closed)', async () => {
    givenService();
    repository.getProviderAvailability.mockResolvedValue([]);
    const tomorrow = new Date(inOneDay()); // 10:00 SAST
    const attempt = bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    });
    if (tomorrow.getUTCDay() === 0) await expect(attempt).rejects.toThrow('outside the provider');
    else await expect(attempt).resolves.toBeTruthy();
  });

  test('visit the business: only when the provider offers it; stored with the business address', async () => {
    givenService();
    await expect(bookingService.createBooking(customer, {
      atBusiness: true, providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    })).rejects.toThrow('does not take visits');
    repository.getProviderById.mockResolvedValue({
      ...verifiedProvider, offers_visit: true, street_address: '5 Salon St', city: 'Pretoria'
    });
    const booking = await bookingService.createBooking(customer, {
      atBusiness: true, providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    });
    expect(booking).toMatchObject({ at_business: true, service_address: '5 Salon St, Pretoria', service_location: null });
  });

  test('house call: refused when the provider does not do them; needs an address', async () => {
    givenService();
    repository.getProviderById.mockResolvedValue({ ...verifiedProvider, offers_house_call: false, offers_visit: true });
    await expect(bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    })).rejects.toThrow('does not do house calls');
    repository.getProviderById.mockResolvedValue(verifiedProvider);
    await expect(bookingService.createBooking(customer, {
      providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    })).rejects.toThrow('Enter the address');
  });

  test('a fixed-price booking holds one slot of the provider\'s slot length', async () => {
    givenService();
    repository.getProviderById.mockResolvedValue({ ...verifiedProvider, slot_minutes: 120 });
    const booking = await bookingService.createBooking(customer, {
      address: '12 Main Rd, Pretoria', providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    });
    expect(new Date(booking.scheduled_end) - new Date(booking.scheduled_start)).toBe(2 * 3600000);
  });

  test('rejects provider booking creation', async () => {
    await expect(bookingService.createBooking(providerUser, {
      providerId: 'provider-1', serviceId: 'service-1', scheduledStart: inOneDay()
    })).rejects.toThrow('not allowed');
  });

  // ---------------- accept / PIN ----------------
  test('provider cannot accept before the booking fee is paid', async () => {
    repository.getBookingById.mockResolvedValue({ id: 'booking-1', provider_id: 'provider-1', status: 'pending', booking_fee_status: 'pending' });
    await expect(bookingService.acceptBooking(providerUser, 'booking-1')).rejects.toThrow('not paid the booking fee');
  });

  test('provider cannot accept without bank details (payout needs somewhere to go)', async () => {
    repository.getBookingById.mockResolvedValue({ id: 'booking-1', provider_id: 'provider-1', status: 'pending', booking_fee_status: 'paid' });
    payoutService.hasPayoutDetails.mockResolvedValue(false);
    await expect(bookingService.acceptBooking(providerUser, 'booking-1')).rejects.toThrow('bank details');
    expect(repository.updateBooking).not.toHaveBeenCalled();
  });

  test('customer can choose cash for the balance only after completion (saved on the server)', async () => {
    repository.getBookingById.mockResolvedValue({ id: 'booking-1', customer_id: 'customer-1', status: 'accepted', balance_status: 'pending' });
    await expect(bookingService.chooseCashBalance(customer, 'booking-1')).rejects.toThrow('after the job is completed');
    repository.getBookingById.mockResolvedValue({ id: 'booking-1', customer_id: 'customer-1', status: 'completed', balance_status: 'pending' });
    const booking = await bookingService.chooseCashBalance(customer, 'booking-1');
    expect(repository.updateBooking).toHaveBeenCalledWith('booking-1', ['completed'], { balance_payment_method: 'cash' }, { balance_status: 'pending' });
    expect(booking.balance_payment_method).toBe('cash');
  });

  test('accepting stores only the PIN hash and never returns it', async () => {
    repository.getBookingById.mockResolvedValue({ id: 'booking-1', provider_id: 'provider-1', status: 'pending', booking_fee_status: 'paid' });
    const booking = await bookingService.acceptBooking(providerUser, 'booking-1');

    const updates = repository.updateBooking.mock.calls[0][2];
    expect(updates.status).toBe('accepted');
    expect(updates.arrival_pin_hash).toBe(hashArrivalPin('booking-1', deriveArrivalPin('booking-1')));
    expect(updates.arrival_pin_hash).not.toContain(deriveArrivalPin('booking-1'));
    expect(booking).not.toHaveProperty('arrival_pin_hash');
  });

  test('customer can see the PIN once accepted; the provider cannot', async () => {
    const accepted = {
      id: 'booking-1', customer_id: 'customer-1', provider_id: 'provider-1', status: 'accepted', arrival_pin_hash: 'x', arrival_pin_attempts: 1
    };
    repository.getBookingById.mockResolvedValue(accepted);
    const pin = await bookingService.getArrivalPin(customer, 'booking-1');
    expect(pin).toEqual({ bookingId: 'booking-1', pin: deriveArrivalPin('booking-1'), attemptsLeft: 4 });
    expect(pin.pin).toMatch(/^\d{4}$/);
    await expect(bookingService.getArrivalPin(providerUser, 'booking-1')).rejects.toThrow('not allowed');
  });

  test('correct PIN starts the job', async () => {
    const pin = deriveArrivalPin('booking-1');
    repository.getBookingById.mockResolvedValue({
      id: 'booking-1', provider_id: 'provider-1', status: 'accepted', arrival_pin_attempts: 0, arrival_pin_hash: hashArrivalPin('booking-1', pin)
    });
    const booking = await bookingService.startBooking(providerUser, 'booking-1', pin);
    expect(repository.updateBooking).toHaveBeenCalledWith('booking-1', ['accepted'], expect.objectContaining({
      status: 'in_progress', arrival_pin_verified_at: expect.any(String)
    }), { arrival_pin_attempts: 0 });
    expect(booking.status).toBe('in_progress');
  });

  test('wrong PIN counts an attempt and does not start the job', async () => {
    const pin = deriveArrivalPin('booking-1');
    const wrong = pin === '0000' ? '1111' : '0000';
    repository.getBookingById.mockResolvedValue({
      id: 'booking-1', provider_id: 'provider-1', status: 'accepted', arrival_pin_attempts: 2, arrival_pin_hash: hashArrivalPin('booking-1', pin)
    });
    await expect(bookingService.startBooking(providerUser, 'booking-1', wrong)).rejects.toThrow('2 tries left');
    expect(repository.updateBooking).toHaveBeenCalledWith('booking-1', ['accepted'], { arrival_pin_attempts: 3 }, { arrival_pin_attempts: 2 });
  });

  test('after 5 wrong PINs the job cannot be started', async () => {
    repository.getBookingById.mockResolvedValue({
      id: 'booking-1', provider_id: 'provider-1', status: 'accepted', arrival_pin_attempts: 5, arrival_pin_hash: 'x'
    });
    await expect(bookingService.startBooking(providerUser, 'booking-1', '1234')).rejects.toThrow('Too many wrong PINs');
    expect(repository.updateBooking).not.toHaveBeenCalled();
  });

  test('a job can only be completed after it was started with the PIN', async () => {
    repository.getBookingById.mockResolvedValue({ id: 'booking-1', provider_id: 'provider-1', status: 'accepted' });
    await expect(bookingService.completeBooking(providerUser, 'booking-1')).rejects.toThrow('PIN entered on arrival');
  });

  // ---------------- decline / cancel refunds ----------------
  test('provider decline refunds the fee', async () => {
    const booking = { id: 'booking-1', provider_id: 'provider-1', status: 'pending', booking_fee_status: 'paid' };
    repository.getBookingById.mockResolvedValue(booking);
    paymentService.refundBookingFee.mockResolvedValue(true);
    const result = await bookingService.declineBooking(providerUser, 'booking-1', 'Fully booked');
    expect(paymentService.refundBookingFee).toHaveBeenCalledWith(booking);
    expect(result).toMatchObject({ status: 'rejected', cancelled_by: 'provider', feeRefund: 'refunded' });
  });

  test('a failed refund does not undo the decline (admin follow-up)', async () => {
    repository.getBookingById.mockResolvedValue({ id: 'booking-1', provider_id: 'provider-1', status: 'pending', booking_fee_status: 'paid' });
    paymentService.refundBookingFee.mockRejectedValue(new Error('PayFast down'));
    const result = await bookingService.declineBooking(providerUser, 'booking-1');
    expect(result).toMatchObject({ status: 'rejected', feeRefund: 'failed' });
  });

  test('customer cancelling while pending gets the fee back', async () => {
    repository.getBookingById.mockResolvedValue({
      id: 'booking-1', customer_id: 'customer-1', provider_id: 'provider-1', status: 'pending', booking_fee_status: 'paid', scheduled_start: inOneDay()
    });
    paymentService.refundBookingFee.mockResolvedValue(true);
    const result = await bookingService.cancelBooking(customer, 'booking-1');
    expect(result.feeRefund).toBe('refunded');
  });

  test('customer cancelling after acceptance keeps the fee as deposit', async () => {
    repository.getBookingById.mockResolvedValue({
      id: 'booking-1',
      customer_id: 'customer-1',
      provider_id: 'provider-1',
      status: 'accepted',
      booking_fee_status: 'paid',
      scheduled_start: new Date(Date.now() + 5 * 86400000).toISOString()
    });
    const result = await bookingService.cancelBooking(customer, 'booking-1');
    expect(result.feeRefund).toBe('kept');
    expect(paymentService.refundBookingFee).not.toHaveBeenCalled();
  });

  test('booking responses never contain the PIN hash', async () => {
    repository.getBookingById.mockResolvedValue({ id: 'booking-1', customer_id: 'customer-1', arrival_pin_hash: 'secret-hash' });
    expect(await bookingService.getBooking(customer, 'booking-1')).not.toHaveProperty('arrival_pin_hash');
    repository.listBookings.mockResolvedValue({ bookings: [{ id: 'b', arrival_pin_hash: 'secret-hash' }], total: 1 });
    const list = await bookingService.listBookings(customer, {});
    expect(list.bookings[0]).not.toHaveProperty('arrival_pin_hash');
  });

  test('the provider sees the customer phone number only once the booking is accepted', () => {
    const row = {
      id: 'b1', customer_id: 'customer-1', status: 'pending', customer: { full_name: 'Pat', phone_number: '+27821234567' },
      service_location: '0101000020E61000009B3AF4CA5A313C40046C4BE11DBF39C0', arrival_pin_hash: 'x'
    };
    expect(bookingService.publicBooking(row, providerUser).customer.phone_number).toBeNull();
    expect(bookingService.publicBooking({ ...row, status: 'accepted' }, providerUser).customer.phone_number).toBe('+27821234567');
    expect(bookingService.publicBooking(row, customer).customer.phone_number).toBe('+27821234567'); // their own
    const shown = bookingService.publicBooking(row, customer);
    expect(shown.service_location.latitude).toBeCloseTo(-25.7465, 3); // map point as plain numbers
    expect(shown).not.toHaveProperty('arrival_pin_hash');
  });
});
