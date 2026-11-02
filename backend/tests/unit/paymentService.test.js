import { jest } from '@jest/globals';

const paymentRepository = {
  getBookingById: jest.fn(),
  getProviderByUserId: jest.fn(),
  getUserById: jest.fn(),
  getPaymentById: jest.fn(),
  getPaymentByBookingId: jest.fn(),
  createPayment: jest.fn(),
  updatePayment: jest.fn(),
  listBookingIdsForCustomer: jest.fn(),
  listBookingIdsForProvider: jest.fn(),
  listPayments: jest.fn()
};
const payfast = {
  createPayment: jest.fn(),
  verifyItn: jest.fn(),
  processRefund: jest.fn()
};

jest.unstable_mockModule('../../src/repositories/paymentRepository.js', () => paymentRepository);
jest.unstable_mockModule('../../src/integrations/payfast.js', () => payfast);
const paymentService = await import('../../src/services/paymentService.js');

describe('Payment service', () => {
  const originalEnvironment = { ...process.env };

  beforeAll(() => {
    process.env.API_BASE_URL = 'https://api.example.test';
    process.env.FRONTEND_URL = 'https://app.example.test';
  });

  afterAll(() => {
    process.env = originalEnvironment;
  });

  beforeEach(() => jest.clearAllMocks());

  test('uses the confirmed booking amount when creating a payment intent', async () => {
    paymentRepository.getBookingById.mockResolvedValue({
      id: 'booking-1',
      customer_id: 'customer-1',
      provider_id: 'provider-1',
      status: 'confirmed',
      total_price: '450.00'
    });
    paymentRepository.getPaymentByBookingId.mockResolvedValue(null);
    paymentRepository.createPayment.mockResolvedValue({ id: 'payment-1', status: 'pending', amount: 450 });
    paymentRepository.getUserById.mockResolvedValue({ email: 'customer@example.test', full_name: 'Test Customer' });
    payfast.createPayment.mockResolvedValue({ url: 'https://sandbox.payfast.test/eng/process', payload: { amount: '450.00' } });

    const result = await paymentService.createPaymentIntent(
      { id: 'customer-1', role: 'customer' },
      'booking-1'
    );

    expect(paymentRepository.createPayment).toHaveBeenCalledWith(expect.objectContaining({
      booking_id: 'booking-1', amount: 450, status: 'pending', method: 'payfast'
    }));
    expect(payfast.createPayment).toHaveBeenCalledWith(expect.objectContaining({ amount: 450, reference: 'payment-1' }));
    expect(result.redirectUrl).toContain('payfast');
  });

  test('client confirmation only reads status and never updates payment state', async () => {
    paymentRepository.getPaymentById.mockResolvedValue({ id: 'payment-1', booking_id: 'booking-1', status: 'pending' });
    paymentRepository.getBookingById.mockResolvedValue({ id: 'booking-1', customer_id: 'customer-1', provider_id: 'provider-1' });

    const payment = await paymentService.confirmPayment(
      { id: 'customer-1', role: 'customer' },
      'payment-1'
    );

    expect(payment.status).toBe('pending');
    expect(paymentRepository.updatePayment).not.toHaveBeenCalled();
  });

  test('ignores an invalid PayFast ITN without mutating payment', async () => {
    payfast.verifyItn.mockResolvedValue(false);

    const result = await paymentService.processPayFastItn({ custom_str1: 'payment-1' }, '192.0.2.1');

    expect(result).toEqual({ accepted: false, processed: false });
    expect(paymentRepository.getPaymentById).not.toHaveBeenCalled();
    expect(paymentRepository.updatePayment).not.toHaveBeenCalled();
  });

  test('marks a pending payment paid only after a verified matching ITN', async () => {
    payfast.verifyItn.mockResolvedValue(true);
    paymentRepository.getPaymentById.mockResolvedValue({ id: 'payment-1', booking_id: 'booking-1', status: 'pending', amount: 450 });
    paymentRepository.updatePayment.mockResolvedValue({ id: 'payment-1', status: 'paid' });

    const result = await paymentService.processPayFastItn({
      custom_str1: 'payment-1',
      payment_status: 'COMPLETE',
      amount_gross: '450.00',
      pf_payment_id: 'pf-transaction-1'
    }, '192.0.2.1');

    expect(paymentRepository.updatePayment).toHaveBeenCalledWith('payment-1', ['pending'], expect.objectContaining({
      status: 'paid', payfast_payment_id: 'pf-transaction-1'
    }));
    expect(result.processed).toBe(true);
  });
});