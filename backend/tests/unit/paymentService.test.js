import { jest } from '@jest/globals';

const paymentRepository = {
  getBookingById: jest.fn(),
  getProviderByUserId: jest.fn(),
  getUserById: jest.fn(),
  getPaymentById: jest.fn(),
  getPaymentByBookingAndPurpose: jest.fn(),
  updateBookingPaymentState: jest.fn(),
  createPayout: jest.fn(),
  getPayoutByBookingId: jest.fn(),
  createPayment: jest.fn(),
  createReceipt: jest.fn(),
  updatePayment: jest.fn(),
  listBookingIdsForCustomer: jest.fn(),
  listBookingIdsForProvider: jest.fn(),
  listPayments: jest.fn(),
  getReceiptByPaymentId: jest.fn()
};
const payfast = {
  createPayment: jest.fn(),
  verifyItn: jest.fn(),
  processRefund: jest.fn()
};

jest.unstable_mockModule('../../src/repositories/paymentRepository.js', () => paymentRepository);
jest.unstable_mockModule('../../src/integrations/payfast.js', () => payfast);
const paymentService = await import('../../src/services/paymentService.js');

const customer = { id: 'customer-1', role: 'customer' };
const pendingBooking = {
  id: 'booking-1',
  customer_id: 'customer-1',
  provider_id: 'provider-1',
  status: 'pending',
  total_amount: '500.00',
  booking_fee_amount: '75.00',
  booking_fee_status: 'pending',
  balance_amount: '425.00',
  balance_status: 'pending'
};

describe('Payment service', () => {
  const originalEnvironment = { ...process.env };

  beforeAll(() => {
    process.env.API_BASE_URL = 'https://api.example.test';
    process.env.FRONTEND_URL = 'https://app.example.test';
  });

  afterAll(() => {
    process.env = originalEnvironment;
  });

  beforeEach(() => {
    jest.clearAllMocks();
    paymentRepository.getUserById.mockResolvedValue({ email: 'customer@example.test', full_name: 'Test Customer' });
    payfast.createPayment.mockResolvedValue({ url: 'https://sandbox.payfast.test/eng/process', payload: {} });
    paymentRepository.updateBookingPaymentState.mockResolvedValue({ id: 'booking-1' });
  });

  test('booking fee checkout charges only the 15% fee while the booking is pending', async () => {
    paymentRepository.getBookingById.mockResolvedValue(pendingBooking);
    paymentRepository.getPaymentByBookingAndPurpose.mockResolvedValue(null);
    paymentRepository.createPayment.mockResolvedValue({ id: 'payment-1', payment_status: 'pending', amount: 75 });

    const result = await paymentService.createPaymentIntent(customer, 'booking-1', 'booking_fee');

    expect(paymentRepository.createPayment).toHaveBeenCalledWith(expect.objectContaining({
      booking_id: 'booking-1',
      amount: 75,
      purpose: 'booking_fee',
      method: 'card',
      gateway_provider: 'payfast'
    }));
    expect(payfast.createPayment).toHaveBeenCalledWith(expect.objectContaining({ amount: 75, reference: 'payment-1' }));
    expect(result).toMatchObject({ purpose: 'booking_fee', amount: 75 });
  });

  test('balance checkout is refused before the job is completed', async () => {
    paymentRepository.getBookingById.mockResolvedValue({ ...pendingBooking, status: 'accepted' });
    await expect(paymentService.createPaymentIntent(customer, 'booking-1', 'balance'))
      .rejects.toThrow('after the job is completed');
    expect(paymentRepository.createPayment).not.toHaveBeenCalled();
  });

  test('balance checkout charges price minus fee after completion', async () => {
    paymentRepository.getBookingById.mockResolvedValue({ ...pendingBooking, status: 'completed', booking_fee_status: 'paid' });
    paymentRepository.getPaymentByBookingAndPurpose.mockResolvedValue(null);
    paymentRepository.createPayment.mockResolvedValue({ id: 'payment-2', payment_status: 'pending', amount: 425 });

    const result = await paymentService.createPaymentIntent(customer, 'booking-1', 'balance');

    expect(paymentRepository.createPayment).toHaveBeenCalledWith(expect.objectContaining({ amount: 425, purpose: 'balance' }));
    expect(result.amount).toBe(425);
  });

  test('refuses to charge a fee that is already paid', async () => {
    paymentRepository.getBookingById.mockResolvedValue({ ...pendingBooking, booking_fee_status: 'paid' });
    await expect(paymentService.createPaymentIntent(customer, 'booking-1', 'booking_fee')).rejects.toThrow('already paid');
  });

  test('client confirmation only reads status and never updates payment state', async () => {
    paymentRepository.getPaymentById.mockResolvedValue({ id: 'payment-1', booking_id: 'booking-1', payment_status: 'pending' });
    paymentRepository.getBookingById.mockResolvedValue({ id: 'booking-1', customer_id: 'customer-1', provider_id: 'provider-1' });

    const payment = await paymentService.confirmPayment(customer, 'payment-1');

    expect(payment.payment_status).toBe('pending');
    expect(paymentRepository.updatePayment).not.toHaveBeenCalled();
  });

  test('ignores an invalid PayFast ITN without mutating payment', async () => {
    payfast.verifyItn.mockResolvedValue(false);

    const result = await paymentService.processPayFastItn({ custom_str1: 'payment-1' }, '192.0.2.1');

    expect(result).toEqual({ accepted: false, processed: false });
    expect(paymentRepository.getPaymentById).not.toHaveBeenCalled();
    expect(paymentRepository.updatePayment).not.toHaveBeenCalled();
  });

  test('a verified fee ITN marks the payment and the booking fee paid', async () => {
    payfast.verifyItn.mockResolvedValue(true);
    paymentRepository.getPaymentById.mockResolvedValue({
      id: 'payment-1', booking_id: 'booking-1', payment_status: 'pending', amount: 75, purpose: 'booking_fee'
    });
    paymentRepository.updatePayment.mockResolvedValue({
      id: 'payment-1', booking_id: 'booking-1', payment_status: 'paid', purpose: 'booking_fee'
    });
    paymentRepository.getBookingById.mockResolvedValue(pendingBooking);

    const result = await paymentService.processPayFastItn({
      custom_str1: 'payment-1', payment_status: 'COMPLETE', amount_gross: '75.00', pf_payment_id: 'pf-1'
    }, '192.0.2.1');

    expect(paymentRepository.updatePayment).toHaveBeenCalledWith('payment-1', ['pending'], expect.objectContaining({
      payment_status: 'paid', transaction_reference: 'pf-1'
    }));
    expect(paymentRepository.createReceipt).toHaveBeenCalledWith('payment-1');
    expect(paymentRepository.updateBookingPaymentState).toHaveBeenCalledWith('booking-1', {}, { booking_fee_status: 'paid' });
    expect(paymentRepository.createPayout).not.toHaveBeenCalled();
    expect(result.processed).toBe(true);
  });

  test('a verified balance ITN creates the payout with 10% commission', async () => {
    payfast.verifyItn.mockResolvedValue(true);
    paymentRepository.getPaymentById.mockResolvedValue({
      id: 'payment-2', booking_id: 'booking-1', payment_status: 'pending', amount: 425, purpose: 'balance'
    });
    paymentRepository.updatePayment.mockResolvedValue({
      id: 'payment-2', booking_id: 'booking-1', payment_status: 'paid', purpose: 'balance'
    });
    paymentRepository.getBookingById.mockResolvedValue({ ...pendingBooking, status: 'completed' });

    await paymentService.processPayFastItn({
      custom_str1: 'payment-2', payment_status: 'COMPLETE', amount_gross: '425.00', pf_payment_id: 'pf-2'
    }, '192.0.2.1');

    expect(paymentRepository.updateBookingPaymentState).toHaveBeenCalledWith('booking-1', {}, {
      balance_status: 'paid', balance_payment_method: 'card'
    });
    expect(paymentRepository.createPayout).toHaveBeenCalledWith(expect.objectContaining({
      booking_id: 'booking-1',
      provider_id: 'provider-1',
      gross_amount: 500,
      commission_rate: 0.1,
      commission_amount: 50,
      cash_collected_amount: 0
    }));
  });

  test('ITN with a different amount is rejected', async () => {
    payfast.verifyItn.mockResolvedValue(true);
    paymentRepository.getPaymentById.mockResolvedValue({
      id: 'payment-1', booking_id: 'booking-1', payment_status: 'pending', amount: 75, purpose: 'booking_fee'
    });
    await expect(paymentService.processPayFastItn({
      custom_str1: 'payment-1', payment_status: 'COMPLETE', amount_gross: '1.00'
    }, '192.0.2.1')).rejects.toThrow('does not match');
    expect(paymentRepository.updatePayment).not.toHaveBeenCalled();
  });

  test('cash balance: provider confirms, payout subtracts the cash already collected', async () => {
    paymentRepository.getBookingById.mockResolvedValue({ ...pendingBooking, status: 'completed', booking_fee_status: 'paid' });
    paymentRepository.getProviderByUserId.mockResolvedValue({ id: 'provider-1' });
    paymentRepository.createPayment.mockResolvedValue({ id: 'payment-3' });
    paymentRepository.createPayout.mockImplementation(async (payout) => payout);

    const { payout } = await paymentService.recordCashBalance({ id: 'provider-user-1', role: 'provider' }, 'booking-1');

    expect(paymentRepository.createPayment).toHaveBeenCalledWith(expect.objectContaining({
      amount: 425, purpose: 'balance', method: 'cash', payment_status: 'paid', gateway_provider: null
    }));
    // ConnectLocal holds the 75 fee; provider gets 500 - 50 commission - 425 cash = 25
    expect(payout).toMatchObject({ gross_amount: 500, commission_amount: 50, cash_collected_amount: 425 });
  });

  test('another provider cannot confirm cash for this booking', async () => {
    paymentRepository.getBookingById.mockResolvedValue({ ...pendingBooking, status: 'completed' });
    paymentRepository.getProviderByUserId.mockResolvedValue({ id: 'provider-2' });
    await expect(paymentService.recordCashBalance({ id: 'x', role: 'provider' }, 'booking-1')).rejects.toThrow('do not own');
  });

  test('refundBookingFee refunds a paid fee through PayFast and records it', async () => {
    paymentRepository.getPaymentByBookingAndPurpose.mockResolvedValue({
      id: 'payment-1', payment_status: 'paid', amount: 75, transaction_reference: 'pf-1'
    });

    const refunded = await paymentService.refundBookingFee({ ...pendingBooking, booking_fee_status: 'paid' });

    expect(refunded).toBe(true);
    expect(payfast.processRefund).toHaveBeenCalledWith('pf-1', 75);
    expect(paymentRepository.updateBookingPaymentState).toHaveBeenCalledWith(
      'booking-1',
      { booking_fee_status: 'paid' },
      { booking_fee_status: 'refunded' }
    );
  });

  test('refundBookingFee does nothing when the fee was never paid', async () => {
    expect(await paymentService.refundBookingFee(pendingBooking)).toBe(false);
    expect(payfast.processRefund).not.toHaveBeenCalled();
  });
});
