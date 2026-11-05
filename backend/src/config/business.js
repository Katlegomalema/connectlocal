/**
 * Business rules from CLAUDE.md, in one place.
 * The database enforces the same limits (check constraints), so changing a number here alone is not enough.
 */

export const BOOKING_FEE_RATE = 0.15; // 15% booking fee (deposit), paid by card when booking
export const COMMISSION_RATE = 0.10; // ConnectLocal keeps 10% of the job price

export const ARRIVAL_PIN_MAX_ATTEMPTS = 5;

export const PHONE_OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
export const PHONE_OTP_MAX_ATTEMPTS = 5;
export const PHONE_OTP_MAX_PER_HOUR = 5;

export const MAX_BOOKING_QUANTITY = 100;

/** Round to cents without floating-point drift (e.g. 0.1 + 0.2). */
export const roundMoney = (value) => Math.round((Number(value) + Number.EPSILON) * 100) / 100;

export const bookingFeeFor = (total) => roundMoney(Number(total) * BOOKING_FEE_RATE);
export const commissionFor = (total) => roundMoney(Number(total) * COMMISSION_RATE);
