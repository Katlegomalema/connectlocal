/**
 * Booking Service
 * Business logic for booking management
 */

import * as bookingRepository from '../repositories/bookingRepository.js';
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

  const service = await bookingRepository.getServiceById(bookingData.serviceId);
  if (!service.active || service.provider_id !== bookingData.providerId) {
    throw new NotFoundError('Active service not found for this provider');
  }

  const provider = await bookingRepository.getProviderById(service.provider_id);
  if (!provider.is_active || provider.verification_status !== 'verified') {
    throw new ConflictError('Provider is not approved to receive bookings');
  }

  const durationMinutes = Number(service.duration_minutes);
  const totalPrice = Number(service.base_price);
  if (!Number.isFinite(durationMinutes) || durationMinutes <= 0 || !Number.isFinite(totalPrice) || totalPrice < 0) {
    throw new ValidationError('Service has invalid duration or price');
  }

  const scheduledStart = parseStartTime(bookingData.scheduledStart);
  const scheduledEnd = new Date(scheduledStart.getTime() + durationMinutes * 60000);
  const hasConflict = await bookingRepository.hasBookingConflict(
    service.provider_id,
    scheduledStart.toISOString(),
    scheduledEnd.toISOString()
  );
  if (hasConflict) throw new ConflictError('The provider time slot is unavailable');

  return bookingRepository.createBooking({
    customer_id: actor.id,
    provider_id: service.provider_id,
    service_id: service.id,
    scheduled_start: scheduledStart.toISOString(),
    scheduled_end: scheduledEnd.toISOString(),
    status: 'pending',
    service_price_at_booking: totalPrice,
    duration_minutes_at_booking: durationMinutes,
    total_amount: totalPrice,
    notes: bookingData.notes || null
  });
};

export const getBooking = async (actor, bookingId) => {
  const booking = await bookingRepository.getBookingById(bookingId);
  await assertBookingParty(actor, booking);
  return booking;
};

export const listBookings = async (actor, { status, page: pageValue, limit: limitValue } = {}) => {
  requireRole(actor, ['customer', 'provider', 'admin']);
  if (status && ![...ACTIVE_STATUSES, ...TERMINAL_STATUSES].includes(status)) {
    throw new ValidationError('Invalid booking status');
  }

  const { page, limit } = makePage(pageValue, limitValue);
  let filters = { status, page, limit };
  if (actor.role === 'customer') filters.customerId = actor.id;
  if (actor.role === 'provider') {
    const provider = await getProviderForActor(actor);
    filters.providerId = provider.id;
  }
  return bookingRepository.listBookings(filters);
};

export const acceptBooking = async (actor, bookingId) => {
  const provider = await getProviderForActor(actor);
  const booking = await bookingRepository.getBookingById(bookingId);
  if (booking.provider_id !== provider.id) throw new AuthorizationError('You do not own this booking');
  if (booking.status !== 'pending') throw new ConflictError('Only pending bookings can be accepted');

  return bookingRepository.updateBooking(bookingId, ['pending'], { status: 'accepted' });
};

export const declineBooking = async (actor, bookingId, reason) => {
  const provider = await getProviderForActor(actor);
  const booking = await bookingRepository.getBookingById(bookingId);
  if (booking.provider_id !== provider.id) throw new AuthorizationError('You do not own this booking');
  if (booking.status !== 'pending') throw new ConflictError('Only pending bookings can be declined');

  return bookingRepository.updateBooking(bookingId, ['pending'], {
    status: 'rejected',
    cancellation_reason: reason || null
  });
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

  return bookingRepository.updateBooking(bookingId, RESCHEDULABLE_STATUSES, {
    scheduled_start: scheduledStart.toISOString(),
    scheduled_end: scheduledEnd.toISOString(),
    status: 'pending'
  });
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

  return bookingRepository.updateBooking(bookingId, ACTIVE_STATUSES, {
    status: 'cancelled',
    cancellation_reason: reason || null
  });
};

export const startBooking = async (actor, bookingId) => {
  const provider = await getProviderForActor(actor);
  const booking = await bookingRepository.getBookingById(bookingId);
  if (booking.provider_id !== provider.id) throw new AuthorizationError('You do not own this booking');
  if (booking.status !== 'accepted') throw new ConflictError('Only accepted bookings can be started');
  return bookingRepository.updateBooking(bookingId, ['accepted'], { status: 'in_progress' });
};

export const completeBooking = async (actor, bookingId) => {
  const provider = await getProviderForActor(actor);
  const booking = await bookingRepository.getBookingById(bookingId);
  if (booking.provider_id !== provider.id) throw new AuthorizationError('You do not own this booking');
  if (!['accepted', 'in_progress'].includes(booking.status)) {
    throw new ConflictError('Only accepted or in-progress bookings can be completed');
  }
  return bookingRepository.updateBooking(bookingId, ['accepted', 'in_progress'], { status: 'completed' });
};

export default {
  createBooking,
  getBooking,
  listBookings,
  acceptBooking,
  declineBooking,
  rescheduleBooking,
  cancelBooking,
  startBooking,
  completeBooking
};
