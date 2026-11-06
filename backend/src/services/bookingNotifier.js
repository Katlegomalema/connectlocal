/**
 * Booking notifications: tells the customer or the provider what happened to a booking (in-app list,
 * plus a push message when the person has a registered device).
 *
 * Never throws: a notification problem must not undo or fail the booking action that caused it.
 */

import * as bookingRepository from '../repositories/bookingRepository.js';
import * as notificationService from './notificationService.js';
import logger from '../utils/logger.js';

/** R450 / R67.50 (the app shows money the same way). */
export const money = (value) => {
  const cents = Math.round(Number(value) * 100);
  return cents % 100 === 0 ? `R${cents / 100}` : `R${(cents / 100).toFixed(2)}`;
};

const when = (iso) => {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '';
  return date.toLocaleString('en-ZA', {
    timeZone: 'Africa/Johannesburg', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit'
  });
};

const firstName = (fullName) => String(fullName || '').trim().split(/\s+/)[0] || 'A customer';

/**
 * event -> who is told, and what. `b` is the booking row with service, provider and customer names.
 * `extra`: feeRefund ('refunded' | 'failed' | 'kept' | 'not_paid'), rating, method.
 */
const EVENTS = {
  requested: (b) => [{
    to: 'provider',
    type: 'booking',
    title: b.at_business ? 'New booking request' : 'New house call request',
    body: `${firstName(b.customer?.full_name)} booked ${b.service} for ${when(b.scheduled_start)}`
      + `${b.at_business ? ' (they will visit your business)' : ' (a house call)'}. Accept or decline it in Bookings.`
  }],
  accepted: (b) => [{
    to: 'customer',
    type: 'booking',
    title: 'Booking accepted',
    body: `${b.business} accepted ${b.service} on ${when(b.scheduled_start)}. `
      + 'Give them your 4-digit PIN (in the booking) when they arrive.'
  }],
  declined: (b, { feeRefund }) => [{
    to: 'customer',
    type: 'booking',
    title: 'Booking declined',
    body: `${b.business} can't take ${b.service}.${
      feeRefund === 'refunded' ? ` Your ${money(b.booking_fee_amount)} booking fee was refunded.` : ''
    }${feeRefund === 'failed' ? ' ConnectLocal will refund your booking fee.' : ''}`
  }],
  cancelled: (b, { feeRefund, by }) => (by === 'provider'
    ? [{
      to: 'customer',
      type: 'booking',
      title: 'Booking cancelled',
      body: `${b.business} cancelled ${b.service} on ${when(b.scheduled_start)}.${
        feeRefund === 'refunded' ? ` Your ${money(b.booking_fee_amount)} booking fee was refunded.` : ''}`
    }]
    : [{
      to: 'provider',
      type: 'booking',
      title: 'Booking cancelled',
      body: `${firstName(b.customer?.full_name)} cancelled ${b.service} on ${when(b.scheduled_start)}.`
    }]),
  started: (b) => [{
    to: 'customer',
    type: 'booking',
    title: 'Job started',
    body: `${b.business} arrived and entered your PIN. ${b.service} has started.`
  }],
  completed: (b) => [{
    to: 'customer',
    type: 'payment',
    title: 'Job done: please pay the balance',
    body: `${b.service} is complete. Pay the balance of ${money(b.balance_amount)} by card or cash, then leave a review.`
  }],
  balancePaid: (b, { method }) => [
    {
      to: 'provider',
      type: 'payment',
      title: 'Balance paid',
      body: `${firstName(b.customer?.full_name)} paid the ${money(b.balance_amount)} balance`
        + `${method === 'cash' ? ' in cash' : ' by card'} for ${b.service}. Your payout is on its way.`
    },
    {
      to: 'customer',
      type: 'payment',
      title: 'Payment received',
      body: `Thanks! Your ${money(b.balance_amount)} payment for ${b.service} is recorded. You can now review ${b.business}.`
    }
  ],
  reviewed: (b, { rating }) => [{
    to: 'provider',
    type: 'review',
    title: 'New review',
    body: `${firstName(b.customer?.full_name)} gave ${b.service} ${rating} out of 5 stars.`
  }]
};

export const notifyBookingEvent = async (event, bookingId, extra = {}) => {
  try {
    const build = EVENTS[event];
    if (!build) throw new Error(`Unknown booking event ${event}`);
    const row = await bookingRepository.getBookingById(bookingId);
    const booking = {
      ...row,
      service: row.service?.service_name || 'your booking',
      business: row.provider?.business_name || 'The provider'
    };
    const recipients = { customer: row.customer_id, provider: row.provider?.user_id };
    for (const note of build(booking, extra)) {
      const userId = recipients[note.to];
      if (!userId) continue;
      // eslint-disable-next-line no-await-in-loop -- at most two notes, in order
      await notificationService.sendInAppNotification(userId, {
        type: note.type,
        title: note.title,
        body: note.body,
        relatedEntityType: 'booking',
        relatedEntityId: bookingId
      });
    }
  } catch (error) {
    logger.warn({ err: error, event, bookingId }, 'Booking notification could not be sent');
  }
};

export default { notifyBookingEvent, money };
