/**
 * Input rules for every form. The app has the same rules in lib/features/shared/validators.dart (same
 * messages), so people see a problem while typing; the backend is the final check.
 *
 * Each rule is a zod schema that also cleans the value (trims spaces, normalises phone numbers, ...).
 */

import { z } from 'zod';

// ---- building blocks -----------------------------------------------------------------------------------
/** HTML / script in text that is shown to other people (reviews, chat, descriptions). */
const HTML_OR_SCRIPT = /<\s*\/?\s*[a-z!?]|javascript\s*:|\bon[a-z]+\s*=/i;
// eslint-disable-next-line no-control-regex -- control characters are exactly what this rule removes
const CONTROL_CHARS = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g;

const cleanText = (value) => String(value ?? '').replace(CONTROL_CHARS, '').trim();
const oneLine = (value) => cleanText(value).replace(/\s+/g, ' ');

/** Free text: trimmed, [min]..[max] characters, no HTML or script. */
export const textSchema = (max, { min = 0, label = 'This field' } = {}) => z.string()
  .transform(cleanText)
  .refine((v) => v.length >= min, min > 0 ? `${label} needs at least ${min} characters` : `${label} is required`)
  .refine((v) => v.length <= max, `${label} can have at most ${max} characters`)
  .refine((v) => !HTML_OR_SCRIPT.test(v), `${label} cannot contain HTML or code`);

/** One-line text (titles, names of things): spaces collapsed. */
export const lineSchema = (max, { min = 1, label = 'This field' } = {}) => z.string()
  .transform(oneLine)
  .refine((v) => v.length >= min, `${label} needs at least ${min} character${min === 1 ? '' : 's'}`)
  .refine((v) => v.length <= max, `${label} can have at most ${max} characters`)
  .refine((v) => !HTML_OR_SCRIPT.test(v), `${label} cannot contain HTML or code`);

// ---- people --------------------------------------------------------------------------------------------
/** Letters (any language, so accents too), with single spaces, hyphens or apostrophes between them. */
export const PERSON_NAME = /^\p{L}+(?:[ '’-]\p{L}+)*$/u;

export const personNameSchema = z.string()
  .transform(oneLine)
  .refine((v) => v.length >= 2, 'Name needs at least 2 letters')
  .refine((v) => v.length <= 100, 'Name can have at most 100 characters')
  .refine((v) => PERSON_NAME.test(v), 'Use letters only (spaces, - and \' are fine), no digits or symbols');

export const emailSchema = z.string()
  .transform((v) => cleanText(v).toLowerCase())
  .refine((v) => v.length <= 254, 'Email address is too long')
  .refine((v) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v), 'Enter a valid email address');

/**
 * South African phone number: +27 82 123 4567, 082 123 4567, 0821234567 (spaces/dashes fine).
 * Cleaned to E.164: +27821234567.
 */
export const normaliseSaPhone = (value) => {
  const digits = String(value ?? '').replace(/[\s()-]/g, '');
  if (/^0[1-8]\d{8}$/.test(digits)) return `+27${digits.slice(1)}`;
  if (/^27[1-8]\d{8}$/.test(digits)) return `+${digits}`;
  return digits;
};
export const saPhoneSchema = z.string()
  .transform(normaliseSaPhone)
  .refine((v) => /^\+27[1-8]\d{8}$/.test(v), 'Enter a South African number, e.g. 082 123 4567 or +27 82 123 4567');

/** At least 8 characters with a capital letter, a small letter and a number. */
export const passwordSchema = z.string()
  .min(8, 'Password must be at least 8 characters')
  .max(72, 'Password can have at most 72 characters')
  .regex(/[A-Z]/, 'Password must contain a capital letter')
  .regex(/[a-z]/, 'Password must contain a small letter')
  .regex(/[0-9]/, 'Password must contain a number');

/** South African ID number: 13 digits, a real birth date (YYMMDD), citizenship 0/1, Luhn check digit. */
export const parseSaId = (value, now = new Date()) => {
  const id = String(value ?? '').replace(/\s/g, '');
  if (!/^\d{13}$/.test(id)) return null;
  let sum = 0;
  for (let i = 0; i < 13; i += 1) {
    let digit = Number(id[12 - i]);
    if (i % 2 === 1) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
  }
  if (sum % 10 !== 0) return null;
  const yy = Number(id.slice(0, 2));
  const month = Number(id.slice(2, 4));
  const day = Number(id.slice(4, 6));
  const year = 2000 + yy <= now.getFullYear() ? 2000 + yy : 1900 + yy;
  const birth = new Date(Date.UTC(year, month - 1, day));
  if (birth.getUTCMonth() !== month - 1 || birth.getUTCDate() !== day || birth > now) return null;
  if (Number(id[10]) > 1) return null;
  let age = now.getFullYear() - year;
  if (now.getMonth() + 1 < month || (now.getMonth() + 1 === month && now.getDate() < day)) age -= 1;
  return {
    id, birthDate: birth.toISOString().slice(0, 10), age, citizen: id[10] === '0'
  };
};
export const saIdSchema = z.string()
  .transform((v) => String(v ?? '').replace(/\s/g, ''))
  .refine((v) => parseSaId(v) !== null, 'That South African ID number is not valid');

// ---- businesses and money ------------------------------------------------------------------------------
/** At least one letter; letters, digits, spaces and & . , ' ( ) - only (e.g. "Pat's Plumbing (Pty) Ltd"). */
export const BUSINESS_NAME = /^(?=.*\p{L})[\p{L}\p{N}\s&.,'()-]+$/u;
export const businessNameSchema = z.string()
  .transform(oneLine)
  .refine((v) => v.length >= 2 && v.length <= 150, 'Business name needs 2 to 150 characters')
  .refine((v) => BUSINESS_NAME.test(v), 'Use letters, digits, spaces and & . , \' ( ) - only');

/** CIPC registration number YYYY/NNNNNN/TT; TT = enterprise type (06-10, 21, 23). */
const ENTERPRISE_TYPES = new Set(['06', '07', '08', '09', '10', '21', '23']);
export const checkRegistrationNumber = (value, now = new Date()) => {
  const match = /^(\d{4})\/(\d{6})\/(\d{2})$/.exec(String(value ?? '').trim());
  if (!match) return 'Use the format 2019/123456/07';
  const year = Number(match[1]);
  if (year < 1900 || year > now.getFullYear()) return `The registration year ${match[1]} is not valid`;
  if (!ENTERPRISE_TYPES.has(match[3])) return `The last two digits (${match[3]}) are not a valid company type`;
  return null;
};
export const registrationNumberSchema = z.string()
  .transform((v) => String(v ?? '').trim())
  .superRefine((v, ctx) => {
    const problem = checkRegistrationNumber(v);
    if (problem) ctx.addIssue({ code: z.ZodIssueCode.custom, message: problem });
  });

export const bankAccountSchema = z.string()
  .transform((v) => String(v ?? '').replace(/[\s-]/g, ''))
  .refine((v) => /^\d+$/.test(v), 'Use digits only')
  .refine((v) => v.length >= 9 && v.length <= 11, 'Account numbers have 9 to 11 digits');

export const branchCodeSchema = z.string()
  .transform((v) => String(v ?? '').trim())
  .refine((v) => /^\d{6}$/.test(v), 'Branch codes have 6 digits');

/** Rand amount: more than 0, at most R1 000 000, at most 2 decimals. */
export const priceSchema = z.coerce.number({ invalid_type_error: 'Enter a price, e.g. 350 or 349.99' })
  .refine((v) => Number.isFinite(v) && v > 0, 'The price must be more than R0')
  .refine((v) => v <= 1000000, 'The price can be at most R1 000 000')
  .refine((v) => Math.abs(Math.round(v * 100) - v * 100) < 1e-6, 'Use at most 2 decimals (cents)');

// ---- places and times ------------------------------------------------------------------------------------
export const addressSchema = z.string()
  .transform(oneLine)
  .refine((v) => v.length >= 5, 'Enter the full address (street, suburb, city)')
  .refine((v) => v.length <= 300, 'The address can have at most 300 characters')
  .refine((v) => /\p{L}/u.test(v), 'Enter the full address (street, suburb, city)')
  .refine((v) => !HTML_OR_SCRIPT.test(v), 'The address cannot contain HTML or code');

/** A date/time that is not in the past (a minute of slack for clocks that are slightly off). */
export const futureDateTimeSchema = z.coerce.date({ invalid_type_error: 'Choose a date and time' })
  .refine((d) => !Number.isNaN(d.getTime()), 'Choose a date and time')
  .refine((d) => d.getTime() > Date.now() - 60000, 'That date and time is in the past');

// ---- small things ----------------------------------------------------------------------------------------
export const otpSchema = z.string().regex(/^\d{6}$/, 'The code must be 6 digits');
export const pinSchema = z.string().regex(/^\d{4}$/, 'The PIN must be 4 digits');

export const paginationSchema = z.object({
  page: z.number().int().positive().default(1),
  limit: z.number().int().min(1).max(100)
    .default(20)
});

export const coordinatesSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180)
});

export const ratingSchema = z.number().int().min(1).max(5);

export const userRoleSchema = z.enum(['customer', 'provider', 'admin']);

/** Legacy name kept for older imports: any E.164 number. New code uses saPhoneSchema. */
export const phoneSchema = saPhoneSchema;
