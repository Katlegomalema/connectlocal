/**
 * Payout Service
 *
 * - Bank details: validated, account number encrypted (utils/encryption.js), only the last 4 digits ever
 *   leave the server. Required before a provider can accept bookings.
 * - Automatic payouts (CLAUDE.md: the admin never marks payouts paid): processPendingPayouts() runs on a
 *   timer (startPayoutScheduler) and right after a payout is created.
 *
 * There is no bank-transfer provider connected yet. PAYOUT_MODE decides what a "transfer" is:
 *   simulated (default while PayFast is in sandbox): the payout is marked paid with a SIM-... reference.
 *   off (default with PAYFAST_MODE=live): payouts stay pending until a real transfer provider is added.
 */

import crypto from 'node:crypto';
import * as payoutRepository from '../repositories/payoutRepository.js';
import * as providerRepository from '../repositories/providerRepository.js';
import * as userRepository from '../repositories/userRepository.js';
import * as notificationService from './notificationService.js';
import { encryptField } from '../utils/encryption.js';
import { isSandbox } from '../integrations/payfast.js';
import logger from '../utils/logger.js';
import { AuthorizationError, NotFoundError, ValidationError } from '../utils/errors.js';

export const ACCOUNT_TYPES = ['Cheque / Current', 'Savings', 'Transmission'];

const getOwnProvider = async (actor) => {
  if (actor?.role !== 'provider') throw new AuthorizationError('Only providers have payout details');
  const provider = await providerRepository.getProviderByUserId(actor.id);
  if (!provider) throw new NotFoundError('Provider profile not found');
  return provider;
};

/** What the app may see: never the account number, only its last 4 digits. */
const publicDetails = (row) => (row ? {
  bankName: row.bank_name,
  accountHolderName: row.account_holder_name,
  accountType: row.account_type,
  branchCode: row.branch_code,
  accountLast4: row.account_last4,
  maskedAccount: `•••• ${row.account_last4}`,
  updatedAt: row.updated_at
} : null);

// Same rule as the app (shared/verification.dart): the holder must be the provider or their business.
const IGNORED_NAME_WORDS = new Set(['pty', 'ltd', 'cc', 'mr', 'mrs', 'ms', 'miss', 'dr']);
const nameTokens = (value) => String(value || '').toLowerCase().replace(/[^a-z\s]/g, ' ')
  .split(/\s+/)
  .filter((t) => t && !IGNORED_NAME_WORDS.has(t));

export const holderNameMatches = (holder, { personName, businessName = '' }) => {
  const h = nameTokens(holder);
  if (!h.length) return false;
  const person = nameTokens(personName);
  if (person.length >= 2) {
    const first = person[0];
    const surname = person[person.length - 1];
    if (h.includes(surname) && h.some((t) => t === first || (t.length === 1 && t === first[0]))) return true;
  }
  const business = nameTokens(businessName);
  return business.length > 0 && business.every((t) => h.includes(t));
};

export const getPayoutDetails = async (actor) => {
  const provider = await getOwnProvider(actor);
  return publicDetails(await payoutRepository.getPayoutDetails(provider.id));
};

export const savePayoutDetails = async (actor, input) => {
  const provider = await getOwnProvider(actor);
  const bankName = String(input.bankName || '').trim();
  const holder = String(input.accountHolderName || '').trim();
  const accountNumber = String(input.accountNumber || '').replace(/[\s-]/g, '');
  const branchCode = String(input.branchCode || '').trim();

  if (bankName.length < 2 || bankName.length > 100) throw new ValidationError('Choose your bank');
  if (!ACCOUNT_TYPES.includes(input.accountType)) throw new ValidationError(`accountType must be one of: ${ACCOUNT_TYPES.join(', ')}`);
  if (!/^\d{9,11}$/.test(accountNumber)) throw new ValidationError('Account numbers have 9 to 11 digits');
  if (!/^\d{6}$/.test(branchCode)) throw new ValidationError('Branch codes have 6 digits');
  const user = await userRepository.getUserById(actor.id);
  if (!holderNameMatches(holder, { personName: user.full_name, businessName: provider.business_name })) {
    throw new ValidationError('The account holder must be you or your business');
  }

  const saved = await payoutRepository.savePayoutDetails(provider.id, {
    bank_name: bankName,
    account_holder_name: holder,
    account_type: input.accountType,
    branch_code: branchCode,
    account_number_encrypted: encryptField(accountNumber),
    account_last4: accountNumber.slice(-4)
  });
  // Payouts waiting for bank details can go now.
  // eslint-disable-next-line no-use-before-define -- defined below; only called later, at run time
  setImmediate(() => processPendingPayouts().catch((error) => logger.error({ err: error }, 'Payout run failed')));
  return publicDetails(saved);
};

/** For acceptBooking: a provider needs bank details first. */
export const hasPayoutDetails = async (providerId) => Boolean(
  (await payoutRepository.getPayoutDetails(providerId))?.account_number_encrypted
);

export const listMyPayouts = async (actor) => {
  const provider = await getOwnProvider(actor);
  const rows = await payoutRepository.listPayoutsForProvider(provider.id);
  return rows.map((row) => ({
    id: row.id,
    bookingId: row.booking_id,
    serviceName: row.booking?.service?.service_name ?? null,
    jobDate: row.booking?.scheduled_start ?? null,
    grossAmount: Number(row.gross_amount),
    commissionRate: Number(row.commission_rate),
    commissionAmount: Number(row.commission_amount),
    cashCollectedAmount: Number(row.cash_collected_amount),
    payoutAmount: Number(row.payout_amount),
    status: row.status,
    reference: row.payout_reference,
    note: row.failure_reason,
    paidAt: row.paid_at,
    createdAt: row.created_at
  }));
};

let warnedLiveSimulated = false;

/** simulated (sandbox only) | off. Simulated payouts are never allowed with live PayFast (no fake "paid"). */
export const payoutMode = () => {
  const mode = (process.env.PAYOUT_MODE || (isSandbox() ? 'simulated' : 'off')).toLowerCase();
  if (mode === 'simulated' && !isSandbox()) {
    if (!warnedLiveSimulated) {
      logger.warn('PAYOUT_MODE=simulated is ignored with PAYFAST_MODE=live: payouts stay pending until a real transfer provider is connected');
      warnedLiveSimulated = true;
    }
    return 'off';
  }
  return ['simulated', 'off'].includes(mode) ? mode : 'off';
};

/** A payout left in 'processing' this long (crash between the two steps) is retried. */
export const STUCK_PROCESSING_MINUTES = 10;

const notifySafely = async (userId, notification) => {
  try {
    await notificationService.sendInAppNotification(userId, notification);
  } catch (error) {
    logger.warn({ err: error, userId }, 'Notification could not be sent');
  }
};

/**
 * Pays every pending payout whose provider has bank details. Safe to run often and in parallel: each payout
 * only moves pending -> processing -> paid if nobody else moved it first.
 */
export const processPendingPayouts = async ({ limit = 50 } = {}) => {
  const mode = payoutMode();
  const summary = {
    mode, paid: 0, waitingForBankDetails: 0, skipped: 0
  };
  if (mode === 'off') return summary;

  // A run that died between "processing" and "paid" must not leave the provider unpaid forever.
  const stuckBefore = new Date(Date.now() - STUCK_PROCESSING_MINUTES * 60000).toISOString();
  summary.retried = (await payoutRepository.resetStuckProcessing(stuckBefore)).length;

  for (const payout of await payoutRepository.listPendingPayouts(limit)) {
    // eslint-disable-next-line no-await-in-loop -- one at a time; each step depends on the previous one
    if (!(await hasPayoutDetails(payout.provider_id))) {
      if (payout.failure_reason !== 'Waiting for bank details') {
        // eslint-disable-next-line no-await-in-loop
        await payoutRepository.updatePayoutIf(payout.id, 'pending', { failure_reason: 'Waiting for bank details' });
      }
      summary.waitingForBankDetails += 1;
      continue;
    }
    // eslint-disable-next-line no-await-in-loop
    const claimed = await payoutRepository.updatePayoutIf(payout.id, 'pending', { status: 'processing', failure_reason: null });
    if (!claimed) {
      summary.skipped += 1;
      continue;
    }
    // Simulated transfer (no bank-transfer provider yet). The reference says so.
    const reference = `SIM-${crypto.randomBytes(5).toString('hex').toUpperCase()}`;
    // eslint-disable-next-line no-await-in-loop
    const paid = await payoutRepository.updatePayoutIf(payout.id, 'processing', {
      status: 'paid', paid_at: new Date().toISOString(), payout_reference: reference
    });
    if (!paid) continue;
    summary.paid += 1;
    // eslint-disable-next-line no-await-in-loop
    const owner = await payoutRepository.getProviderOwner(payout.provider_id);
    if (owner?.user_id) {
      // eslint-disable-next-line no-await-in-loop
      await notifySafely(owner.user_id, {
        type: 'payment',
        title: 'Payout sent',
        body: `R${Number(payout.payout_amount).toFixed(2)} was paid to your bank account (ref ${reference}, sandbox).`,
        relatedEntityType: 'payout',
        relatedEntityId: payout.id
      });
    }
  }
  if (summary.paid || summary.waitingForBankDetails) logger.info(summary, 'Payout run');
  return summary;
};

let timer;

/** Runs processPendingPayouts every PAYOUT_INTERVAL_SECONDS (default 60). Not started in tests. */
export const startPayoutScheduler = () => {
  if (timer || process.env.NODE_ENV === 'test') return;
  const seconds = Math.max(10, Number(process.env.PAYOUT_INTERVAL_SECONDS) || 60);
  timer = setInterval(() => {
    processPendingPayouts().catch((error) => logger.error({ err: error }, 'Payout run failed'));
  }, seconds * 1000);
  timer.unref();
  logger.info({ mode: payoutMode(), everySeconds: seconds }, 'Automatic payouts scheduled');
};

export const stopPayoutScheduler = () => {
  clearInterval(timer);
  timer = undefined;
};

export default {
  getPayoutDetails,
  savePayoutDetails,
  hasPayoutDetails,
  listMyPayouts,
  processPendingPayouts,
  startPayoutScheduler,
  stopPayoutScheduler,
  holderNameMatches
};
