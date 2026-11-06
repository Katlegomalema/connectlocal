import { jest } from '@jest/globals';

process.env.CODE_HASH_SECRET = process.env.CODE_HASH_SECRET || 'test-only-secret-test-only-secret-test-only-secret';

const otpRepository = {
  countCodesSince: jest.fn(),
  closeOpenCodes: jest.fn(),
  createCode: jest.fn(),
  getOpenCode: jest.fn(),
  recordFailedAttempt: jest.fn(),
  consumeCode: jest.fn(),
  findUserByPhone: jest.fn()
};
const userRepository = { getUserById: jest.fn(), updateUser: jest.fn() };

jest.unstable_mockModule('../../src/config/supabase.js', () => ({ supabase: { auth: {} }, supabaseAdmin: { auth: {} } }));
jest.unstable_mockModule('../../src/repositories/phoneOtpRepository.js', () => otpRepository);
jest.unstable_mockModule('../../src/repositories/userRepository.js', () => userRepository);
const authService = await import('../../src/services/authService.js');
const { hashOtp } = await import('../../src/utils/secureCodes.js');

const user = { id: 'user-1', role: 'customer' };
const PHONE = '+27821234567';
const openCode = (code, overrides = {}) => ({
  id: 'otp-1',
  user_id: 'user-1',
  phone_number: PHONE,
  code_hash: hashOtp('user-1', PHONE, code),
  attempts: 0,
  expires_at: new Date(Date.now() + 60000).toISOString(),
  consumed_at: null,
  ...overrides
});

describe('Phone OTP', () => {
  const originalEnv = { ...process.env };
  afterAll(() => { process.env = originalEnv; });

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.NODE_ENV = 'test';
    process.env.PHONE_OTP_DEV_ECHO = 'true';
    otpRepository.findUserByPhone.mockResolvedValue(null);
    otpRepository.countCodesSince.mockResolvedValue(0);
    otpRepository.createCode.mockImplementation(async ({ expiresAt }) => ({ id: 'otp-1', expires_at: expiresAt }));
    otpRepository.consumeCode.mockResolvedValue({ id: 'otp-1' });
  });

  test('stores only a hash, valid for at most 5 minutes, and closes older codes first', async () => {
    const result = await authService.sendPhoneOtp(user, PHONE);

    expect(result.devCode).toMatch(/^\d{6}$/);
    const saved = otpRepository.createCode.mock.calls[0][0];
    expect(saved.codeHash).toBe(hashOtp('user-1', PHONE, result.devCode));
    expect(saved.codeHash).not.toContain(result.devCode);
    expect(new Date(saved.expiresAt).getTime() - Date.now()).toBeLessThanOrEqual(5 * 60000);
    expect(otpRepository.closeOpenCodes.mock.invocationCallOrder[0])
      .toBeLessThan(otpRepository.createCode.mock.invocationCallOrder[0]);
  });

  test('the code is never returned in production', async () => {
    process.env.NODE_ENV = 'production';
    const result = await authService.sendPhoneOtp(user, PHONE);
    expect(result).not.toHaveProperty('devCode');
  });

  test('a number owned by another account is refused', async () => {
    otpRepository.findUserByPhone.mockResolvedValue({ id: 'someone-else' });
    await expect(authService.sendPhoneOtp(user, PHONE)).rejects.toThrow('another account');
  });

  test('rate limited to 5 codes per hour', async () => {
    otpRepository.countCodesSince.mockResolvedValue(5);
    await expect(authService.sendPhoneOtp(user, PHONE)).rejects.toThrow('Too many codes');
  });

  test('correct code verifies the phone once (single use)', async () => {
    otpRepository.getOpenCode.mockResolvedValue(openCode('123456'));
    otpRepository.recordFailedAttempt.mockResolvedValue({ attempts: 1 }); // the try is used up first
    const result = await authService.verifyPhoneWithOtp(user, '123456');
    expect(result).toEqual({ id: 'user-1', phone: PHONE, phoneVerified: true });
    expect(otpRepository.consumeCode).toHaveBeenCalledWith('otp-1');
    expect(userRepository.updateUser).toHaveBeenCalledWith('user-1', { phone_number: PHONE, phone_verified: true });
  });

  test('guesses at the same moment: one gets the try, the others are refused', async () => {
    otpRepository.getOpenCode.mockResolvedValue(openCode('123456', { attempts: 0 }));
    otpRepository.recordFailedAttempt.mockResolvedValueOnce({ attempts: 1 }).mockResolvedValue(null);
    const results = await Promise.allSettled(['111111', '222222', '333333'].map((g) => authService.verifyPhoneWithOtp(user, g)));
    const messages = results.map((r) => r.reason?.message || '');
    expect(messages.filter((m) => m.startsWith('Wrong code'))).toHaveLength(1);
    expect(messages.filter((m) => m.includes('Another check'))).toHaveLength(2);
  });

  test('wrong code counts an attempt and does not verify', async () => {
    otpRepository.getOpenCode.mockResolvedValue(openCode('123456', { attempts: 1 }));
    otpRepository.recordFailedAttempt.mockResolvedValue({ attempts: 2 });
    await expect(authService.verifyPhoneWithOtp(user, '654321')).rejects.toThrow('3 tries left');
    expect(otpRepository.recordFailedAttempt).toHaveBeenCalledWith('otp-1', 1);
    expect(userRepository.updateUser).not.toHaveBeenCalled();
  });

  test('the 5th wrong code closes the code', async () => {
    otpRepository.getOpenCode.mockResolvedValue(openCode('123456', { attempts: 4 }));
    otpRepository.recordFailedAttempt.mockResolvedValue({ attempts: 5 });
    await expect(authService.verifyPhoneWithOtp(user, '654321')).rejects.toThrow('Request a new one');
    expect(otpRepository.consumeCode).toHaveBeenCalledWith('otp-1');
  });

  test('an expired code is refused even if correct', async () => {
    otpRepository.getOpenCode.mockResolvedValue(openCode('123456', { expires_at: new Date(Date.now() - 1000).toISOString() }));
    await expect(authService.verifyPhoneWithOtp(user, '123456')).rejects.toThrow('expired');
    expect(userRepository.updateUser).not.toHaveBeenCalled();
  });

  test('a code used by a parallel request cannot be used again', async () => {
    otpRepository.getOpenCode.mockResolvedValue(openCode('123456'));
    otpRepository.consumeCode.mockResolvedValue(null);
    await expect(authService.verifyPhoneWithOtp(user, '123456')).rejects.toThrow('already used');
    expect(userRepository.updateUser).not.toHaveBeenCalled();
  });
});
