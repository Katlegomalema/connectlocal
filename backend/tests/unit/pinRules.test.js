import { jest } from '@jest/globals';

process.env.CODE_HASH_SECRET = process.env.CODE_HASH_SECRET || 'test-only-secret-test-only-secret-test-only-secret';

const repository = {
  getBookingById: jest.fn(),
  getProviderByUserId: jest.fn(),
  updateBooking: jest.fn()
};
jest.unstable_mockModule('../../src/repositories/bookingRepository.js', () => repository);
jest.unstable_mockModule('../../src/services/paymentService.js', () => ({ refundBookingFee: jest.fn(), recordCashBalance: jest.fn() }));
jest.unstable_mockModule('../../src/services/payoutService.js', () => ({ hasPayoutDetails: jest.fn(async () => true) }));
jest.unstable_mockModule('../../src/services/bookingNotifier.js', () => ({ notifyBookingEvent: jest.fn(async () => {}) }));
const bookingService = await import('../../src/services/bookingService.js');
const {
  deriveArrivalPin, hashArrivalPin, hashesMatch, checkoutToken, checkoutTokenValid
} = await import('../../src/utils/secureCodes.js');

const provider = { id: 'provider-user-1', role: 'provider' };
const acceptedBooking = (attempts = 0) => ({
  id: 'booking-1',
  provider_id: 'provider-1',
  status: 'accepted',
  arrival_pin_attempts: attempts,
  arrival_pin_hash: hashArrivalPin('booking-1', deriveArrivalPin('booking-1'))
});
const wrongPin = () => (deriveArrivalPin('booking-1') === '0000' ? '1111' : '0000');

describe('arrival PIN rules', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    repository.getProviderByUserId.mockResolvedValue({ id: 'provider-1' });
    repository.updateBooking.mockImplementation(async (id, statuses, updates) => ({ id, ...updates }));
  });

  test('PIN is 4 digits, the same every time for a booking, different across bookings', () => {
    const pin = deriveArrivalPin('booking-1');
    expect(pin).toMatch(/^\d{4}$/);
    expect(deriveArrivalPin('booking-1')).toBe(pin);
    const pins = new Set(Array.from({ length: 50 }, (_, i) => deriveArrivalPin(`booking-${i}`)));
    expect(pins.size).toBeGreaterThan(40); // spread out, not one fixed value
  });

  test('only a 64-char HMAC hash is stored; it does not contain the PIN', () => {
    const pin = deriveArrivalPin('booking-1');
    const hash = hashArrivalPin('booking-1', pin);
    expect(hash).toMatch(/^[0-9a-f]{64}$/);
    expect(hash).not.toContain(pin);
    expect(hashesMatch(hash, hashArrivalPin('booking-1', pin))).toBe(true);
    expect(hashesMatch(hash, hashArrivalPin('booking-2', pin))).toBe(false); // bound to the booking
  });

  test('the PIN depends on the server secret', () => {
    const original = process.env.CODE_HASH_SECRET;
    const a = hashArrivalPin('booking-1', '1234');
    process.env.CODE_HASH_SECRET = 'another-secret-another-secret-another-secret!';
    const b = hashArrivalPin('booking-1', '1234');
    process.env.CODE_HASH_SECRET = original;
    expect(a).not.toBe(b);
  });

  test('a malformed PIN is refused without using up a try', async () => {
    repository.getBookingById.mockResolvedValue(acceptedBooking(0));
    await expect(bookingService.startBooking(provider, 'booking-1', '12a4')).rejects.toThrow('4 digits');
    expect(repository.updateBooking).not.toHaveBeenCalled();
  });

  test.each([
    [0, '4 tries left'],
    [3, '1 tries left'],
    [4, 'No tries left']
  ])('wrong PIN after %i wrong tries -> "%s", counter +1', async (attempts, message) => {
    repository.getBookingById.mockResolvedValue(acceptedBooking(attempts));
    await expect(bookingService.startBooking(provider, 'booking-1', wrongPin())).rejects.toThrow(message);
    expect(repository.updateBooking).toHaveBeenCalledWith(
      'booking-1',
      ['accepted'],
      { arrival_pin_attempts: attempts + 1 },
      { arrival_pin_attempts: attempts }
    );
  });

  test('after 4 wrong tries the right PIN still starts the job', async () => {
    repository.getBookingById.mockResolvedValue(acceptedBooking(4));
    const booking = await bookingService.startBooking(provider, 'booking-1', deriveArrivalPin('booking-1'));
    expect(booking.status).toBe('in_progress');
    expect(booking.status_changed_by).toBe('provider-user-1');
  });

  test('after 5 wrong tries even the right PIN is refused', async () => {
    repository.getBookingById.mockResolvedValue(acceptedBooking(5));
    await expect(bookingService.startBooking(provider, 'booking-1', deriveArrivalPin('booking-1')))
      .rejects.toThrow('Too many wrong PINs');
    expect(repository.updateBooking).not.toHaveBeenCalled();
  });

  test('only the booking\'s own provider can enter the PIN', async () => {
    repository.getProviderByUserId.mockResolvedValue({ id: 'provider-2' });
    repository.getBookingById.mockResolvedValue(acceptedBooking(0));
    await expect(bookingService.startBooking(provider, 'booking-1', deriveArrivalPin('booking-1')))
      .rejects.toThrow('do not own');
  });

  test('a PIN cannot start a booking that is not accepted', async () => {
    repository.getBookingById.mockResolvedValue({ ...acceptedBooking(0), status: 'pending' });
    await expect(bookingService.startBooking(provider, 'booking-1', deriveArrivalPin('booking-1')))
      .rejects.toThrow('Only accepted bookings');
  });
});

describe('checkout link tokens', () => {
  test('valid until it expires, bound to the payment', () => {
    const expires = Math.floor(Date.now() / 1000) + 60;
    const token = checkoutToken('payment-1', expires);
    expect(checkoutTokenValid('payment-1', expires, token)).toBe(true);
    expect(checkoutTokenValid('payment-2', expires, token)).toBe(false);
    expect(checkoutTokenValid('payment-1', expires + 1, token)).toBe(false); // expiry cannot be extended
    const past = Math.floor(Date.now() / 1000) - 1;
    expect(checkoutTokenValid('payment-1', past, checkoutToken('payment-1', past))).toBe(false);
  });
});
