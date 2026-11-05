/**
 * Booking Service
 * Business logic for booking management
 */

import * as bookingRepository from '../repositories/bookingRepository.js';
import * as paymentService from './paymentService.js';
import logger from '../utils/logger.js';
import {
  ARRIVAL_PIN_MAX_ATTEMPTS, BOOKING_FEE_RATE, MAX_BOOKING_QUANTITY, bookingFeeFor, roundMoney
} from '../config/business.js';
import {
  deriveArrivalPin, hashArrivalPin, hashesMatch
} from '../utils/secureCodes.js';
import {
  AuthorizationError,
  ConflictError,
  NotFoundError,
  ValidationError
} from '../utils/errors.js';

const ACTIVE_STATUSES = ['pending', 'accepted', 'in_progress'];
const RESCHEDULABLE_STATUSES = ['pending', 'accepted'];
const TERMINAL_STATUSES = ['completed', 'cancelled', 'rejected'];

const parseStartTime = (value) => {
  const date = new Date(value);
  if (!value || Number.isNaN(date.getTime()) || date.getTime() <= Date.now()) {
    throw new ValidationError('scheduledStart must be a valid future date');
  }

  const maxAdvanceDays = Number(process.env.MAX_BOOKING_ADVANCE_DAYS || 365);
  if (date.getTime() > Date.now() + maxAdvanceDays * 86400000) {
    throw new ValidationError(`Bookings cannot be made more than ${maxAdvanceDays} days in advance`);
  }
  return date;
};

const requireRole = (actor, roles) => {
  if (!actor || !roles.includes(actor.role)) {
    throw new AuthorizationError('You are not allowed to perform this booking action');
  }
};

const getProviderForActor = async (actor) => {
  requireRole(actor, ['provider']);
  return bookingRepository.getProviderByUserId(actor.id);
};

const assertBookingParty = async (actor, booking) => {
  if (actor.role === 'admin' || booking.customer_id === actor.id) return;
  if (actor.role === 'provider') {
    const provider = await bookingRepository.getProviderByUserId(actor.id);
    if (provider.id === booking.provider_id) return;
  }
  throw new AuthorizationError('You are not a party to this booking');
};

/** Never send the PIN hash to any client. */
export const publicBooking = (booking) => {
  if (!booking) return booking;
  const copy = { ...booking };
  delete copy.arrival_pin_hash;
  return copy;
};

const getOwnedBookingForProvider = async (actor, bookingId) => {
  const provider = await getProviderForActor(actor);
  const booking = await bookingRepository.getBookingById(bookingId);
  if (booking.provider_id !== provider.id) throw new AuthorizationError('You do not own this booking');
  return booking;
};

/**
 * Price of a booking from the service's pricing type:
 *   fixed   -> base_price, service duration
 *   hourly  -> base_price per hour x hours
 *   package -> the chosen package's price (snapshot of its name)
 */
const priceBooking = async (service, { packageId, hours }) => {
  const pricingType = service.pricing_type || 'fixed';
  if (pricingType === 'package') {
    if (!packageId) throw new ValidationError('packageId is required for this service');
    const pkg = await bookingRepository.getPackageById(packageId);
    if (pkg.service_id !== service.id || !pkg.is_active) throw new NotFoundError('Package not found for this service');
    return {
      pricingType,
      unitPrice: Number(pkg.price),
      quantity: 1,
      durationMinutes: Number(pkg.duration_minutes || service.duration_minutes),
      packageId: pkg.id,
      packageName: pkg.name
    };
  }
  if (packageId) throw new ValidationError('This service is not sold as packages');
  if (pricingType === 'hourly') {
    const quantity = Number(hours);
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > Math.min(24, MAX_BOOKING_QUANTITY)) {
      throw new ValidationError('hours must be a whole number between 1 and 24');
    }
    return {
      pricingType, unitPrice: Number(service.base_price), quantity, durationMinutes: quantity * 60
    };
  }
  if (hours !== undefined) throw new ValidationError('This service has a fixed price; hours are not used');
  return {
    pricingType, unitPrice: Number(service.base_price), quantity: 1, durationMinutes: Number(service.duration_minutes)
  };
};

/** Refund the fee but never let a gateway problem undo the booking decision; admins can retry. */
const tryRefundFee = async (booking) => {
  try {
    return (await paymentService.refundBookingFee(booking)) ? 'refunded' : 'not_paid';
  } catch (error) {
    logger.error({ err: error, bookingId: booking.id }, 'Booking fee refund failed; needs admin follow-up');
    return 'failed';
  }
};

const makePage = (pageValue, limitValue) => {
  const page = Number.parseInt(pageValue, 10) || 1;
  const limit = Number.parseInt(limitValue, 10) || 20;
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new ValidationError('page must be positive and limit must be between 1 and 100');
  }
  return { page, limit };
};

export const createBooking = async (actor, bookingData) => {
  requireRole(actor, ['customer']);
  if (!bookingData.providerId || !bookingData.serviceId) {
    throw new ValidationError('providerId and serviceId are required');
  }

  // Business rule: verified email AND phone before booking.
  const customer = await bookingRepository.getCustomerById(actor.id);
  if (!customer.email_verified || !customer.phone_verified) {
    throw new AuthorizationError('Verify your email address and phone number before booking');
  }

  const service = await bookingRepository.getServiceById(bookingData.serviceId);
  if (!service.active || service.provider_id !== bookingData.providerId) {
    throw new NotFoundError('Active service not found for this provider');
  }

  const provider = await bookingRepository.getProviderById(service.provider_id);
  if (!provider.is_active || provider.verification_status !== 'verified') {
    throw new ConflictError('Provider is not approved to receive bookings');
  }

  const price = await priceBooking(service, bookingData);
  const totalPrice = roundMoney(price.unitPrice * price.quantity);
  if (!Number.isFinite(price.durationMinutes) || price.durationMinutes <= 0
      || !Number.isFinite(totalPrice) || totalPrice <= 0) {
    throw new ValidationError('Service has invalid duration or price');
  }

  const scheduledStart = parseStartTime(bookingData.scheduledStart);
  const scheduledEnd = new Date(scheduledStart.getTime() + price.durationMinutes * 60000);
  const hasConflict = await bookingRepository.hasBookingConflict(
    service.provider_id,
    scheduledStart.toISOString(),
    scheduledEnd.toISOString()
  );
  if (hasConflict) throw new ConflictError('The provider time slot is unavailable');

  const booking = await bookingRepository.createBooking({
    customer_id: actor.id,
    provider_id: service.provider_id,
    service_id: service.id,
    scheduled_start: scheduledStart.toISOString(),
    scheduled_end: scheduledEnd.toISOString(),
    status: 'pending',
    service_price_at_booking: roundMoney(price.unitPrice),
    duration_minutes_at_booking: price.durationMinutes,
    pricing_type_at_booking: price.pricingType,
    package_id: price.packageId || null,
    package_name_at_booking: price.packageName || null,
    quantity: price.quantity,
    total_amount: totalPrice,
    booking_fee_rate: BOOKING_FEE_RATE,
    booking_fee_amount: bookingFeeFor(totalPrice),
    booking_fee_status: 'pending',
    notes: bookingData.notes || null
  });
  return publicBooking(booking);
};

export const getBooking = async (actor, bookingId) => {
  const booking = await bookingRepository.getBookingById(bookingId);
  await assertBookingParty(actor, booking);
  return publicBooking(booking);
};

export const listBookings = async (actor, { status, page: pageValue, limit: limitValue } = {}) => {
  requireRole(actor, ['customer', 'provider', 'admin']);
  if (status && ![...ACTIVE_STATUSES, ...TERMINAL_STATUSES].includes(status)) {
    throw new ValidationError('Invalid booking status');
  }

  const { page, limit } = makePage(pageValue, limitValue);
  const filters = { status, page, limit };
  if (actor.role === 'customer') filters.customerId = actor.id;
  if (actor.role === 'provider') {
    const provider = await getProviderForActor(actor);
    filters.providerId = provider.id;
  }
  const result = await bookingRepository.listBookings(filters);
  return { ...result, bookings: result.bookings.map(publicBooking) };
};

export const acceptBooking = async (actor, bookingId) => {
  const booking = await getOwnedBookingForProvider(actor, bookingId);
  if (booking.status !== 'pending') throw new ConflictError('Only pending bookings can be accepted');
  if (booking.booking_fee_status !== 'paid') {
    throw new ConflictError('The customer has not paid the booking fee yet');
  }

  // The PIN is derived from the booking id; only its hash is stored. The customer sees it via /arrival-pin.
  const updated = await bookingRepository.updateBooking(bookingId, ['pending'], {
    status: 'accepted',
    arrival_pin_hash: hashArrivalPin(booking.id, deriveArrivalPin(booking.id)),
    arrival_pin_attempts: 0,
    arrival_pin_verified_at: null
  });
  return publicBooking(updated);
};

export const declineBooking = async (actor, bookingId, reason) => {
  const booking = await getOwnedBookingForProvider(actor, bookingId);
  if (booking.status !== 'pending') throw new ConflictError('Only pending bookings can be declined');

  const updated = await bookingRepository.updateBooking(bookingId, ['pending'], {
    status: 'rejected',
    cancelled_by: 'provider',
    cancellation_reason: reason || null
  });
  // Business rule: fee refunded when the provider declines.
  const feeRefund = await tryRefundFee(booking);
  return { ...publicBooking(updated), feeRefund };
};

/**
 * Customer only: the 4-digit PIN to give the provider on arrival.
 */
export const getArrivalPin = async (actor, bookingId) => {
  requireRole(actor, ['customer']);
  const booking = await bookingRepository.getBookingById(bookingId);
  if (booking.customer_id !== actor.id) throw new AuthorizationError('You do not own this booking');
  if (booking.status !== 'accepted' || !booking.arrival_pin_hash) {
    throw new ConflictError('The arrival PIN is only available once the provider has accepted');
  }
  return {
    bookingId: booking.id,
    pin: deriveArrivalPin(booking.id),
    attemptsLeft: Math.max(0, ARRIVAL_PIN_MAX_ATTEMPTS - booking.arrival_pin_attempts)
  };
};

export const rescheduleBooking = async (actor, bookingId, scheduledStartValue) => {
  requireRole(actor, ['customer']);
  const booking = await bookingRepository.getBookingById(bookingId);
  if (booking.customer_id !== actor.id) throw new AuthorizationError('You do not own this booking');
  if (!RESCHEDULABLE_STATUSES.includes(booking.status)) {
    throw new ConflictError('This booking cannot be rescheduled');
  }

  const scheduledStart = parseStartTime(scheduledStartValue);
  const durationMs = new Date(booking.scheduled_end).getTime() - new Date(booking.scheduled_start).getTime();
  if (!Number.isFinite(durationMs) || durationMs <= 0) {
    throw new ValidationError('Booking has an invalid scheduled duration');
  }
  const scheduledEnd = new Date(scheduledStart.getTime() + durationMs);
  const hasConflict = await bookingRepository.hasBookingConflict(
    booking.provider_id,
    scheduledStart.toISOString(),
    scheduledEnd.toISOString(),
    bookingId
  );
  if (hasConflict) throw new ConflictError('The provider time slot is unavailable');

  // Back to pending: the provider must accept the new time (the paid fee stays paid; a new PIN hash is set
  // on acceptance).
  const updated = await bookingRepository.updateBooking(bookingId, RESCHEDULABLE_STATUSES, {
    scheduled_start: scheduledStart.toISOString(),
    scheduled_end: scheduledEnd.toISOString(),
    status: 'pending',
    arrival_pin_hash: null,
    arrival_pin_attempts: 0
  });
  return publicBooking(updated);
};

export const cancelBooking = async (actor, bookingId, reason) => {
  requireRole(actor, ['customer', 'provider']);
  const booking = await bookingRepository.getBookingById(bookingId);
  await assertBookingParty(actor, booking);
  if (TERMINAL_STATUSES.includes(booking.status)) {
    throw new ConflictError('This booking can no longer be cancelled');
  }

  const cancellationWindowHours = Number(process.env.CANCELLATION_POLICY_HOURS || 24);
  const hoursUntilBooking = (new Date(booking.scheduled_start).getTime() - Date.now()) / 3600000;
  if (actor.role === 'customer' && booking.status === 'accepted' && hoursUntilBooking < cancellationWindowHours) {
    throw new ConflictError('The cancellation window has passed');
  }

  if (booking.status === 'in_progress') {
    throw new ConflictError('A job in progress cannot be cancelled; complete it or contact support');
  }

  const updated = await bookingRepository.updateBooking(bookingId, ['pending', 'accepted'], {
    status: 'cancelled',
    cancelled_by: actor.role,
    cancellation_reason: reason || null
  });
  // Business rule: fee refunded if the customer cancels while pending. A provider cancelling also refunds
  // (the customer did nothing wrong). A customer cancelling after acceptance keeps the fee as the deposit.
  const refundable = booking.status === 'pending' || actor.role === 'provider';
  const feeRefund = refundable ? await tryRefundFee(booking) : 'kept';
  return { ...publicBooking(updated), feeRefund };
};

/**
 * Provider arrives and enters the customer's PIN: the job starts (in_progress).
 */
export const startBooking = async (actor, bookingId, pin) => {
  const booking = await getOwnedBookingForProvider(actor, bookingId);
  if (booking.status !== 'accepted') throw new ConflictError('Only accepted bookings can be started');
  if (typeof pin !== 'string' || !/^\d{4}$/.test(pin)) throw new ValidationError('pin must be 4 digits');

  const attempts = Number(booking.arrival_pin_attempts) || 0;
  if (attempts >= ARRIVAL_PIN_MAX_ATTEMPTS) {
    throw new ConflictError('Too many wrong PINs. Ask the customer to contact support.');
  }
  if (!booking.arrival_pin_hash) throw new ConflictError('This booking has no arrival PIN yet');

  // The attempt counter is part of the update condition, so two parallel guesses cannot both count as one.
  if (!hashesMatch(booking.arrival_pin_hash, hashArrivalPin(booking.id, pin))) {
    await bookingRepository.updateBooking(bookingId, ['accepted'], {
      arrival_pin_attempts: attempts + 1
    }, { arrival_pin_attempts: attempts });
    const left = ARRIVAL_PIN_MAX_ATTEMPTS - attempts - 1;
    throw new ValidationError(left > 0 ? `Wrong PIN. ${left} tries left.` : 'Wrong PIN. No tries left.');
  }

  const updated = await bookingRepository.updateBooking(bookingId, ['accepted'], {
    status: 'in_progress',
    arrival_pin_verified_at: new Date().toISOString()
  }, { arrival_pin_attempts: attempts });
  return publicBooking(updated);
};

export const completeBooking = async (actor, bookingId) => {
  const booking = await getOwnedBookingForProvider(actor, bookingId);
  if (booking.status !== 'in_progress') {
    throw new ConflictError('Only a job in progress (PIN entered on arrival) can be completed');
  }
  const updated = await bookingRepository.updateBooking(bookingId, ['in_progress'], { status: 'completed' });
  return publicBooking(updated);
};

/**
 * Provider confirms the customer paid the balance in cash (creates the payment, receipt and payout).
 */
export const confirmCashBalance = async (actor, bookingId) => paymentService.recordCashBalance(actor, bookingId);

export default {
  createBooking,
  getBooking,
  listBookings,
  acceptBooking,
  declineBooking,
  rescheduleBooking,
  cancelBooking,
  startBooking,
  completeBooking,
  getArrivalPin,
  confirmCashBalance
};
