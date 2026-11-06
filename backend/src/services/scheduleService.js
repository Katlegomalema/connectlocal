/**
 * Schedule Service: how a provider can be booked (visit the business and/or house call), their working
 * hours and slot length, and which times are already taken.
 */

import * as providerRepository from '../repositories/providerRepository.js';
import * as bookingRepository from '../repositories/bookingRepository.js';
import { toLatLng } from '../utils/geo.js';
import {
  BOOKING_GAP_MINUTES, SLOT_LENGTHS, hoursFromRows, rowsFromHours
} from '../utils/schedule.js';
import { AuthorizationError, NotFoundError, ValidationError } from '../utils/errors.js';

const BUSY_DAYS_AHEAD = 60;

const hasBusinessLocation = (provider) => Boolean(toLatLng(provider.location) || provider.street_address?.trim());

/** Booking options + working hours of a provider (no private data). */
const scheduleOf = async (provider) => {
  const rows = await providerRepository.getProviderAvailability(provider.id);
  return {
    providerId: provider.id,
    offersVisit: Boolean(provider.offers_visit),
    offersHouseCall: provider.offers_house_call !== false,
    slotMinutes: provider.slot_minutes || 60,
    gapMinutes: BOOKING_GAP_MINUTES,
    hasBusinessLocation: hasBusinessLocation(provider),
    businessAddress: [provider.street_address, provider.suburb, provider.city].filter((p) => p?.trim()).join(', '),
    // The standard hours until the provider saves their own.
    customHours: rows.length > 0,
    workingHours: hoursFromRows(rows)
  };
};

/**
 * Public: what the booking screen needs. [busy] are the times already held by other bookings (start/end
 * only, nothing about the customer), from now until BUSY_DAYS_AHEAD days ahead.
 */
export const getPublicSchedule = async (providerId) => {
  const provider = await providerRepository.getProviderById(providerId);
  if (!provider || provider.verification_status !== 'verified' || provider.is_active === false) {
    throw new NotFoundError('Provider not found');
  }
  const from = new Date();
  const to = new Date(from.getTime() + BUSY_DAYS_AHEAD * 86400000);
  const busy = await bookingRepository.listBusyTimes(provider.id, from.toISOString(), to.toISOString());
  return {
    ...(await scheduleOf(provider)),
    busy: busy.map((b) => ({ start: b.scheduled_start, end: b.scheduled_end }))
  };
};

const getOwnProvider = async (actor) => {
  if (actor?.role !== 'provider') throw new AuthorizationError('Only providers have a schedule');
  const provider = await providerRepository.getProviderByUserId(actor.id);
  if (!provider) throw new NotFoundError('Provider profile not found');
  return provider;
};

export const getOwnSchedule = async (actor) => scheduleOf(await getOwnProvider(actor));

/**
 * Saves booking options, slot length and working hours.
 * input: { offersVisit, offersHouseCall, slotMinutes, workingHours: [{ day: 1-7, open, close }] }
 */
export const saveOwnSchedule = async (actor, input = {}) => {
  const provider = await getOwnProvider(actor);
  const offersVisit = input.offersVisit ?? Boolean(provider.offers_visit);
  const offersHouseCall = input.offersHouseCall ?? provider.offers_house_call !== false;
  const slotMinutes = input.slotMinutes ?? provider.slot_minutes ?? 60;

  if (!offersVisit && !offersHouseCall) throw new ValidationError('Choose at least one way customers can book you.');
  if (offersVisit && !hasBusinessLocation(provider)) {
    throw new ValidationError('Add your business address first, so customers can find you.');
  }
  if (!SLOT_LENGTHS.includes(slotMinutes)) {
    throw new ValidationError(`slotMinutes must be one of ${SLOT_LENGTHS.join(', ')}`);
  }

  if (input.workingHours !== undefined) {
    const hours = input.workingHours;
    const days = new Set();
    for (const h of hours) {
      if (!Number.isInteger(h.day) || h.day < 1 || h.day > 7 || days.has(h.day)) {
        throw new ValidationError('Each working day must appear once (1 = Monday ... 7 = Sunday)');
      }
      const valid = Number.isInteger(h.open) && Number.isInteger(h.close) && h.open >= 0 && h.close <= 1440;
      if (!valid || h.close <= h.open) {
        throw new ValidationError('Working hours must end after they start, within the same day');
      }
      if (h.close - h.open < slotMinutes) {
        throw new ValidationError('Each working day must be at least one slot long');
      }
      days.add(h.day);
    }
    if (!hours.length) throw new ValidationError('Open at least one day a week');
    await providerRepository.replaceProviderAvailability(provider.id, rowsFromHours(hours));
  }

  const updated = await providerRepository.updateProvider(provider.id, provider.user_id, {
    offers_visit: offersVisit,
    offers_house_call: offersHouseCall,
    slot_minutes: slotMinutes
  });
  return scheduleOf({ ...provider, ...updated });
};

export default { getPublicSchedule, getOwnSchedule, saveOwnSchedule };
