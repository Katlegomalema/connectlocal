import { jest } from '@jest/globals';

const providerRepository = {
  getProviderById: jest.fn(),
  getProviderByUserId: jest.fn(),
  getProviderAvailability: jest.fn(),
  replaceProviderAvailability: jest.fn(),
  updateProvider: jest.fn()
};
const bookingRepository = { listBusyTimes: jest.fn() };
jest.unstable_mockModule('../../src/repositories/providerRepository.js', () => providerRepository);
jest.unstable_mockModule('../../src/repositories/bookingRepository.js', () => bookingRepository);
const scheduleService = await import('../../src/services/scheduleService.js');
const {
  fitsWorkingHours, hoursFromRows, rowsFromHours, sastParts, STANDARD_HOURS
} = await import('../../src/utils/schedule.js');

const provider = {
  id: 'provider-1', user_id: 'user-1', verification_status: 'verified', is_active: true, offers_visit: false, offers_house_call: true, slot_minutes: 60, location: null, street_address: null
};
const actor = { id: 'user-1', role: 'provider' };

describe('schedule rules', () => {
  test('South African time: 08:00 UTC Monday is Monday 10:00', () => {
    expect(sastParts(new Date('2026-11-09T08:00:00Z'))).toEqual({ day: 1, minutes: 600 });
    expect(sastParts(new Date('2026-11-08T23:30:00Z'))).toEqual({ day: 1, minutes: 90 }); // Sunday UTC = Monday SAST
  });

  test('days: API 1 = Monday ... 7 = Sunday <-> database 0 = Sunday', () => {
    const rows = rowsFromHours([{ day: 7, open: 540, close: 780 }, { day: 1, open: 480, close: 1020 }]);
    expect(rows).toEqual([
      { dayOfWeek: 0, startTime: '09:00:00', endTime: '13:00:00' },
      { dayOfWeek: 1, startTime: '08:00:00', endTime: '17:00:00' }
    ]);
    expect(hoursFromRows([{ day_of_week: 0, start_time: '09:00:00', end_time: '13:00:00' }])).toEqual([{ day: 7, open: 540, close: 780 }]);
    expect(hoursFromRows([])).toBe(STANDARD_HOURS);
  });

  test('a booking must end by closing time', () => {
    const monday10 = new Date('2026-11-09T08:00:00Z');
    expect(fitsWorkingHours(STANDARD_HOURS, monday10, 60)).toBe(true);
    expect(fitsWorkingHours(STANDARD_HOURS, new Date('2026-11-09T14:30:00Z'), 60)).toBe(false); // 16:30 + 1 h > 17:00
    expect(fitsWorkingHours(STANDARD_HOURS, new Date('2026-11-08T08:00:00Z'), 60)).toBe(false); // Sunday closed
  });
});

describe('schedule service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    providerRepository.getProviderByUserId.mockResolvedValue(provider);
    providerRepository.getProviderById.mockResolvedValue(provider);
    providerRepository.getProviderAvailability.mockResolvedValue([]);
    providerRepository.updateProvider.mockImplementation(async (id, userId, updates) => ({ ...provider, ...updates }));
  });

  test('public schedule: options, hours and busy times only (no customer details)', async () => {
    bookingRepository.listBusyTimes.mockResolvedValue([{ scheduled_start: 'a', scheduled_end: 'b' }]);
    const schedule = await scheduleService.getPublicSchedule('provider-1');
    expect(schedule).toMatchObject({
      offersVisit: false, offersHouseCall: true, slotMinutes: 60, gapMinutes: 30, customHours: false, busy: [{ start: 'a', end: 'b' }]
    });
    expect(schedule.workingHours).toBe(STANDARD_HOURS);
  });

  test('an unverified provider has no public schedule', async () => {
    providerRepository.getProviderById.mockResolvedValue({ ...provider, verification_status: 'pending' });
    await expect(scheduleService.getPublicSchedule('provider-1')).rejects.toThrow('not found');
  });

  test('at least one booking option; a visit needs a business address', async () => {
    await expect(scheduleService.saveOwnSchedule(actor, { offersVisit: false, offersHouseCall: false })).rejects.toThrow('at least one');
    await expect(scheduleService.saveOwnSchedule(actor, { offersVisit: true })).rejects.toThrow('business address');
    providerRepository.getProviderByUserId.mockResolvedValue({ ...provider, street_address: '5 Salon St' });
    const saved = await scheduleService.saveOwnSchedule(actor, { offersVisit: true, offersHouseCall: false });
    expect(saved).toMatchObject({ offersVisit: true, offersHouseCall: false });
  });

  test('working hours are validated and saved as one row per day', async () => {
    await expect(scheduleService.saveOwnSchedule(actor, { slotMinutes: 45 })).rejects.toThrow('slotMinutes');
    await expect(scheduleService.saveOwnSchedule(actor, { workingHours: [{ day: 1, open: 600, close: 540 }] })).rejects.toThrow('end after');
    await expect(scheduleService.saveOwnSchedule(actor, {
      workingHours: [{ day: 1, open: 480, close: 1020 }, { day: 1, open: 480, close: 600 }]
    })).rejects.toThrow('once');
    await expect(scheduleService.saveOwnSchedule(actor, { slotMinutes: 240, workingHours: [{ day: 6, open: 540, close: 720 }] }))
      .rejects.toThrow('at least one slot');
    await scheduleService.saveOwnSchedule(actor, { slotMinutes: 120, workingHours: [{ day: 6, open: 540, close: 780 }] });
    expect(providerRepository.replaceProviderAvailability).toHaveBeenCalledWith('provider-1', [
      { dayOfWeek: 6, startTime: '09:00:00', endTime: '13:00:00' }
    ]);
    expect(providerRepository.updateProvider).toHaveBeenCalledWith('provider-1', 'user-1', expect.objectContaining({ slot_minutes: 120 }));
  });

  test('only providers', async () => {
    await expect(scheduleService.getOwnSchedule({ id: 'c', role: 'customer' })).rejects.toThrow('Only providers');
  });
});
