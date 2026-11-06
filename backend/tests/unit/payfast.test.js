import { jest } from '@jest/globals';
import crypto from 'node:crypto';

const axios = { post: jest.fn() };
const dns = { resolve4: jest.fn() };
jest.unstable_mockModule('axios', () => ({ default: axios }));
jest.unstable_mockModule('node:dns/promises', () => ({ default: dns }));

process.env.PAYFAST_MERCHANT_ID = '10000100';
process.env.PAYFAST_MERCHANT_KEY = '46f0cd694581a';
process.env.PAYFAST_PASSPHRASE = 'jt7NOE43FZPn';
delete process.env.PAYFAST_MODE;
const payfast = await import('../../src/integrations/payfast.js');

const md5 = (text) => crypto.createHash('md5').update(text).digest('hex');

describe('PayFast signing', () => {
  test('PHP urlencode rules: spaces as +, and !\'()*~ encoded', () => {
    expect(payfast.phpUrlEncode("Pat O'Brien (test)!*~")).toBe('Pat+O%27Brien+%28test%29%21%2A%7E');
    expect(payfast.phpUrlEncode('https://a.test/x?y=1&z=2')).toBe('https%3A%2F%2Fa.test%2Fx%3Fy%3D1%26z%3D2');
  });

  test('checkout signature uses PayFast field order, skips blanks, adds the passphrase', () => {
    const fields = {
      item_name: 'Booking fee', amount: '67.50', merchant_key: '46f0cd694581a', merchant_id: '10000100', name_first: ''
    };
    const expected = md5('merchant_id=10000100&merchant_key=46f0cd694581a&amount=67.50&item_name=Booking+fee&passphrase=jt7NOE43FZPn');
    expect(payfast.checkoutSignature(fields)).toBe(expected);
  });

  test('createPayment returns the fields in documented order with merchant_key and m_payment_id', async () => {
    const { url, payload } = await payfast.createPayment({
      amount: 67.5,
      return_url: 'https://api.test/return',
      cancel_url: 'https://api.test/cancel',
      notify_url: 'https://api.test/itn',
      first_name: 'Pat',
      last_name: 'Doe',
      email: 'pat@example.test',
      item_name: 'ConnectLocal booking fee (15% deposit)',
      reference: 'payment-1',
      booking_id: 'booking-1'
    });
    expect(url).toBe('https://sandbox.payfast.co.za/eng/process'); // sandbox by default
    expect(Object.keys(payload)).toEqual([
      'merchant_id', 'merchant_key', 'return_url', 'cancel_url', 'notify_url', 'name_first', 'name_last',
      'email_address', 'm_payment_id', 'amount', 'item_name', 'custom_str1', 'custom_str2', 'signature'
    ]);
    expect(payload.amount).toBe('67.50');
    const { signature, ...unsigned } = payload;
    expect(signature).toBe(payfast.checkoutSignature(unsigned));
  });

  test('ITN signature: order received, blanks included', () => {
    const posted = { m_payment_id: 'p1', pf_payment_id: '123', payment_status: 'COMPLETE', item_description: '', amount_gross: '67.50' };
    expect(payfast.itnSignature(posted)).toBe(
      md5('m_payment_id=p1&pf_payment_id=123&payment_status=COMPLETE&item_description=&amount_gross=67.50&passphrase=jt7NOE43FZPn')
    );
  });

  test('API (refund) signature: alphabetical, passphrase included', () => {
    expect(payfast.apiSignature({ version: 'v1', 'merchant-id': '10000100', amount: 6750 })).toBe(
      md5('amount=6750&merchant-id=10000100&passphrase=jt7NOE43FZPn&version=v1')
    );
  });
});

describe('PayFast ITN checks', () => {
  const signed = (fields) => ({ ...fields, signature: payfast.itnSignature(fields) });
  const itn = () => signed({
    m_payment_id: 'payment-1', pf_payment_id: '123', payment_status: 'COMPLETE', amount_gross: '67.50', merchant_id: '10000100'
  });

  beforeEach(() => {
    jest.clearAllMocks();
    dns.resolve4.mockResolvedValue(['197.97.145.144']);
    axios.post.mockResolvedValue({ data: 'VALID' });
  });

  test('accepts a correctly signed ITN from a PayFast address that PayFast confirms', async () => {
    await expect(payfast.verifyItn(itn(), ['10.0.0.1', '197.97.145.144'])).resolves.toBe(true);
    expect(axios.post).toHaveBeenCalledWith('https://sandbox.payfast.co.za/eng/query/validate', expect.any(String), expect.any(Object));
  });

  test('rejects a tampered amount (signature no longer matches)', async () => {
    await expect(payfast.verifyItn({ ...itn(), amount_gross: '1.00' }, ['197.97.145.144'])).resolves.toBe(false);
    expect(axios.post).not.toHaveBeenCalled();
  });

  test('rejects another merchant', async () => {
    await expect(payfast.verifyItn(signed({ ...itn(), merchant_id: '999' }), ['197.97.145.144'])).resolves.toBe(false);
  });

  test('rejects an ITN that does not come from PayFast', async () => {
    await expect(payfast.verifyItn(itn(), ['203.0.113.9'])).resolves.toBe(false);
    expect(axios.post).not.toHaveBeenCalled();
  });

  test('rejects when PayFast says INVALID', async () => {
    axios.post.mockResolvedValue({ data: 'INVALID' });
    await expect(payfast.verifyItn(itn(), ['197.97.145.144'])).resolves.toBe(false);
  });
});
