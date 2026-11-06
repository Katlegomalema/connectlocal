import { jest } from '@jest/globals';

process.env.PAYOUT_ENCRYPTION_KEY = process.env.PAYOUT_ENCRYPTION_KEY || Buffer.alloc(32, 7).toString('base64');

const payoutRepository = {
  getPayoutDetails: jest.fn(),
  savePayoutDetails: jest.fn(),
  listPayoutsForProvider: jest.fn(),
  listPendingPayouts: jest.fn(),
  updatePayoutIf: jest.fn(),
  resetStuckProcessing: jest.fn(async () => []),
  getProviderOwner: jest.fn()
};
const providerRepository = { getProviderByUserId: jest.fn() };
const userRepository = { getUserById: jest.fn() };
const notificationService = { sendInAppNotification: jest.fn() };
const payfast = { isSandbox: jest.fn(() => true) };

jest.unstable_mockModule('../../src/repositories/payoutRepository.js', () => payoutRepository);
jest.unstable_mockModule('../../src/repositories/providerRepository.js', () => providerRepository);
jest.unstable_mockModule('../../src/repositories/userRepository.js', () => userRepository);
jest.unstable_mockModule('../../src/services/notificationService.js', () => notificationService);
jest.unstable_mockModule('../../src/integrations/payfast.js', () => payfast);
const payoutService = await import('../../src/services/payoutService.js');
const { encryptField, decryptField } = await import('../../src/utils/encryption.js');

const provider = { id: 'user-1', role: 'provider' };

describe('encryption', () => {
  test('round trip; the stored value never contains the number; every encryption differs', () => {
    const a = encryptField('62012345678');
    const b = encryptField('62012345678');
    expect(a).toMatch(/^v1:[A-Za-z0-9+/=]+:[A-Za-z0-9+/=]+:[A-Za-z0-9+/=]+$/);
    expect(a).not.toContain('62012345678');
    expect(a).not.toBe(b);
    expect(decryptField(a)).toBe('62012345678');
  });

  test('a tampered value does not decrypt', () => {
    const [v, iv, tag, data] = encryptField('62012345678').split(':');
    const flipped = Buffer.from(data, 'base64');
    flipped[0] ^= 1; // eslint-disable-line no-bitwise
    expect(() => decryptField([v, iv, tag, flipped.toString('base64')].join(':'))).toThrow();
  });
});

describe('payout details', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    providerRepository.getProviderByUserId.mockResolvedValue({ id: 'provider-1', business_name: 'Drain Repair' });
    userRepository.getUserById.mockResolvedValue({ id: 'user-1', full_name: 'Pat Doe' });
    payoutRepository.savePayoutDetails.mockImplementation(async (id, values) => ({ provider_id: id, ...values, updated_at: 'now' }));
    payoutRepository.listPendingPayouts.mockResolvedValue([]);
  });

  test('saves the number encrypted and returns only the last 4 digits', async () => {
    const saved = await payoutService.savePayoutDetails(provider, {
      bankName: 'FNB', accountType: 'Savings', accountHolderName: 'P Doe', accountNumber: '620 1234 5678', branchCode: '250655'
    });
    const stored = payoutRepository.savePayoutDetails.mock.calls[0][1];
    expect(stored.account_number_encrypted).not.toContain('62012345678');
    expect(decryptField(stored.account_number_encrypted)).toBe('62012345678');
    expect(stored.account_last4).toBe('5678');
    expect(saved).toMatchObject({ accountLast4: '5678', maskedAccount: '•••• 5678' });
    expect(JSON.stringify(saved)).not.toContain('62012345678');
    expect(saved).not.toHaveProperty('account_number_encrypted');
  });

  test("someone else's account is refused (holder must be you or your business)", async () => {
    await expect(payoutService.savePayoutDetails(provider, {
      bankName: 'FNB', accountType: 'Savings', accountHolderName: 'John Smith', accountNumber: '62012345678', branchCode: '250655'
    })).rejects.toThrow('must be you or your business');
    await expect(payoutService.savePayoutDetails(provider, {
      bankName: 'FNB', accountType: 'Savings', accountHolderName: 'Drain Repair (Pty) Ltd', accountNumber: '62012345678', branchCode: '250655'
    })).resolves.toBeTruthy();
  });

  test.each([
    [{ accountNumber: '1234' }, '9 to 11 digits'],
    [{ branchCode: '2506' }, '6 digits'],
    [{ accountType: 'Crypto' }, 'accountType']
  ])('invalid input %j is refused', async (override, message) => {
    await expect(payoutService.savePayoutDetails(provider, {
      bankName: 'FNB', accountType: 'Savings', accountHolderName: 'Pat Doe', accountNumber: '62012345678', branchCode: '250655', ...override
    })).rejects.toThrow(message);
    expect(payoutRepository.savePayoutDetails).not.toHaveBeenCalled();
  });
});

describe('automatic payouts', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.PAYOUT_MODE;
    payfast.isSandbox.mockReturnValue(true);
    payoutRepository.getProviderOwner.mockResolvedValue({ user_id: 'user-1' });
    payoutRepository.updatePayoutIf.mockImplementation(async (id, from, updates) => ({ id, ...updates }));
  });

  test('sandbox: a pending payout with bank details is paid (simulated, SIM- reference) and the provider told', async () => {
    payoutRepository.listPendingPayouts.mockResolvedValue([{ id: 'po-1', provider_id: 'provider-1', payout_amount: '405.00', status: 'pending' }]);
    payoutRepository.getPayoutDetails.mockResolvedValue({ account_number_encrypted: 'v1:a:b:c' });

    const summary = await payoutService.processPendingPayouts();

    expect(summary).toMatchObject({ mode: 'simulated', paid: 1 });
    expect(payoutRepository.updatePayoutIf).toHaveBeenNthCalledWith(1, 'po-1', 'pending', { status: 'processing', failure_reason: null });
    expect(payoutRepository.updatePayoutIf).toHaveBeenNthCalledWith(2, 'po-1', 'processing', expect.objectContaining({
      status: 'paid', payout_reference: expect.stringMatching(/^SIM-[0-9A-F]{10}$/)
    }));
    expect(notificationService.sendInAppNotification).toHaveBeenCalledWith('user-1', expect.objectContaining({ title: 'Payout sent' }));
  });

  test('without bank details the payout waits (pending, with a note)', async () => {
    payoutRepository.listPendingPayouts.mockResolvedValue([{ id: 'po-1', provider_id: 'provider-1', payout_amount: '22.50', status: 'pending' }]);
    payoutRepository.getPayoutDetails.mockResolvedValue(null);
    const summary = await payoutService.processPendingPayouts();
    expect(summary).toMatchObject({ paid: 0, waitingForBankDetails: 1 });
    expect(payoutRepository.updatePayoutIf).toHaveBeenCalledWith('po-1', 'pending', { failure_reason: 'Waiting for bank details' });
  });

  test('a payout another run already took is skipped (never paid twice)', async () => {
    payoutRepository.listPendingPayouts.mockResolvedValue([{ id: 'po-1', provider_id: 'provider-1', payout_amount: '405.00', status: 'pending' }]);
    payoutRepository.getPayoutDetails.mockResolvedValue({ account_number_encrypted: 'v1:a:b:c' });
    payoutRepository.updatePayoutIf.mockResolvedValueOnce(null); // claim lost
    const summary = await payoutService.processPendingPayouts();
    expect(summary).toMatchObject({ paid: 0, skipped: 1 });
    expect(payoutRepository.updatePayoutIf).toHaveBeenCalledTimes(1);
  });

  test('payouts stuck in "processing" (interrupted run) are put back to pending first', async () => {
    payoutRepository.listPendingPayouts.mockResolvedValue([]);
    payoutRepository.resetStuckProcessing.mockResolvedValueOnce([{ id: 'po-9' }]);
    const summary = await payoutService.processPendingPayouts();
    expect(summary.retried).toBe(1);
    const before = new Date(payoutRepository.resetStuckProcessing.mock.calls[0][0]).getTime();
    expect(Date.now() - before).toBeGreaterThanOrEqual(10 * 60000 - 1000);
  });

  test('PAYOUT_MODE=simulated is ignored with live PayFast (never a fake "paid")', async () => {
    process.env.PAYOUT_MODE = 'simulated';
    payfast.isSandbox.mockReturnValue(false);
    const summary = await payoutService.processPendingPayouts();
    expect(summary.mode).toBe('off');
    expect(payoutRepository.updatePayoutIf).not.toHaveBeenCalled();
  });

  test('live PayFast without a transfer provider: nothing is paid', async () => {
    payfast.isSandbox.mockReturnValue(false);
    const summary = await payoutService.processPendingPayouts();
    expect(summary.mode).toBe('off');
    expect(payoutRepository.listPendingPayouts).not.toHaveBeenCalled();
  });
});
