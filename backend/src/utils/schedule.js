/**
 * Working hours and booking slots (same rules as the app's lib/features/community/models/schedule.dart).
 *
 * - Days in the API: 1 = Monday ... 7 = Sunday (like Dart's DateTime.weekday).
 *   Days in the database (provider_availability.day_of_week): 0 = Sunday ... 6 = Saturday.
 * - Times are South African local time (SAST, UTC+2 all year, no daylight saving), in minutes since midnight.
 * - Every booking keeps BOOKING_GAP_MINUTES free after it, so two jobs are never back to back.
 */

export const BOOKING_GAP_MINUTES = 30;
export const SLOT_LENGTHS = [30, 60, 120, 240, 480];
const SAST_OFFSET_MINUTES = 120;

/** Used until the provider sets their own: Mon-Fri 8:00-17:00, Sat 9:00-13:00 (same as the app). */
export const STANDARD_HOURS = [1, 2, 3, 4, 5].map((day) => ({ day, open: 480, close: 1020 }))
  .concat([{ day: 6, open: 540, close: 780 }]);

export const apiDayToDb = (day) => day % 7;
export const dbDayToApi = (day) => (day === 0 ? 7 : day);

const toMinutes = (time) => {
  const [h, m] = String(time).split(':').map(Number);
  return h * 60 + m;
};
const toTime = (minutes) => `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}:00`;

/** provider_availability rows -> [{ day, open, close }] (API form). Empty -> the standard hours. */
export const hoursFromRows = (rows) => (rows?.length
  ? rows.map((r) => ({ day: dbDayToApi(r.day_of_week), open: toMinutes(r.start_time), close: toMinutes(r.end_time) }))
    .sort((a, b) => a.day - b.day)
  : STANDARD_HOURS);

/** [{ day, open, close }] -> rows for replaceProviderAvailability. */
export const rowsFromHours = (hours) => hours.map((h) => ({
  dayOfWeek: apiDayToDb(h.day), startTime: toTime(h.open), endTime: toTime(h.close)
}));

/** Weekday (1-7) and minutes since midnight of an instant, in South African time. */
export const sastParts = (date) => {
  const local = new Date(date.getTime() + SAST_OFFSET_MINUTES * 60000);
  const jsDay = local.getUTCDay();
  return { day: jsDay === 0 ? 7 : jsDay, minutes: local.getUTCHours() * 60 + local.getUTCMinutes() };
};

/** True when [minutes] starting at [start] fit inside that day's working hours (SAST). */
export const fitsWorkingHours = (hours, start, minutes) => {
  const { day, minutes: from } = sastParts(start);
  const today = hours.find((h) => h.day === day);
  return Boolean(today) && from >= today.open && from + minutes <= today.close;
};
