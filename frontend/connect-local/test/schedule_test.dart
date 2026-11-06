import 'package:connect_local/core/connect_local_repository.dart';
import 'package:connect_local/features/community/models/models.dart';
import 'package:connect_local/features/community/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Wednesday far in the future, so no slot is "already past".
  final wednesday = DateTime(2030, 1, 2);
  final sunday = DateTime(2030, 1, 6);

  test('slots run from opening time and must end by closing time', () {
    const hours = WorkingHours(days: {DateTime.wednesday: DayHours(480, 1020)}, slotMinutes: 120); // 8:00-17:00
    final starts = hours.slotStarts(wednesday).map((d) => clockLabel(d.hour * 60 + d.minute)).toList();
    // 8, 10, 12, 14 fit; a slot at 16:00 would end at 18:00, after closing.
    expect(starts, ['8:00 AM', '10:00 AM', '12:00 PM', '2:00 PM']);
    expect(hours.slotStarts(sunday), isEmpty, reason: 'closed on Sunday');
  });

  test('a full-day slot gives one slot per day', () {
    const hours = WorkingHours(days: {DateTime.wednesday: DayHours(480, 1020)}, slotMinutes: 480);
    expect(hours.slotStarts(wednesday).length, 1);
  });

  test('working hours survive saving and loading', () {
    const hours = WorkingHours(days: {DateTime.monday: DayHours(540, 780)}, slotMinutes: 30);
    final back = WorkingHours.fromJson(hours.toJson());
    expect(back.slotMinutes, 30);
    expect(back.days[DateTime.monday]!.open, 540);
    expect(back.days[DateTime.monday]!.close, 780);
    expect(back.isOpenOn(wednesday), isFalse);
  });

  test('a booked slot is taken for other customers; a declined one is free again', () {
    final app = AppState();
    final provider = ProviderModel(
      id: 'p1',
      name: 'Barber',
      rating: 0,
      reviews: 0,
      distanceKm: 0,
      services: [],
      workingHours: const WorkingHours(days: {DateTime.wednesday: DayHours(480, 1020)}, slotMinutes: 60),
    );
    app.providers.add(provider);

    final tenAm = DateTime(2030, 1, 2, 10);
    expect(app.slotIsFree('p1', tenAm, 60), isTrue);

    // Someone booked 10:00-11:00 (the server lists it under "busy", without customer details).
    app.setBusyTimes('p1', [(start: tenAm, minutes: 60)]);

    expect(app.slotIsFree('p1', tenAm, 60), isFalse, reason: 'booked');
    expect(app.slotIsFree('p1', DateTime(2030, 1, 2, 9), 120), isFalse, reason: '9-11 overlaps 10-11');
    // 30-minute gap after every booking: 10-11 is booked, so 11:00 is too soon, 11:30 is fine.
    expect(app.slotIsFree('p1', DateTime(2030, 1, 2, 11), 60), isFalse, reason: 'inside the 30-min gap');
    expect(app.slotIsFree('p1', DateTime(2030, 1, 2, 11, 30), 60), isTrue, reason: 'after the gap');
    // And the gap applies before the booking too: 9:00-10:00 would end right when 10:00 starts.
    expect(app.slotIsFree('p1', DateTime(2030, 1, 2, 9), 60), isFalse, reason: 'no gap before 10:00');
    expect(app.slotIsFree('p1', DateTime(2030, 1, 2, 8), 60), isTrue, reason: '8-9 leaves 1 hour before 10:00');
    expect(app.slotIsFree('p1', DateTime(2030, 1, 2, 16, 30), 60), isFalse, reason: 'ends after closing');

    final slots = app.slotsFor('p1', wednesday, 60);
    expect(slots.firstWhere((s) => s.start == tenAm).free, isFalse);

    // Declined or cancelled bookings are no longer listed as busy by the server.
    app.setBusyTimes('p1', const []);
    expect(app.slotIsFree('p1', tenAm, 60), isTrue, reason: 'declined: the slot is free again');
  });

  test('the server schedule is read into working hours, options and taken times', () {
    final schedule = ProviderSchedule.fromJson({
      'offersVisit': true,
      'offersHouseCall': false,
      'slotMinutes': 120,
      'workingHours': [
        {'day': 6, 'open': 540, 'close': 780},
      ],
      'busy': [
        {'start': '2030-01-05T08:00:00Z', 'end': '2030-01-05T10:00:00Z'},
      ],
    });
    expect(schedule.offersVisit, isTrue);
    expect(schedule.offersHouseCall, isFalse);
    expect(schedule.hours.slotMinutes, 120);
    expect(schedule.hours.days[DateTime.saturday]!.open, 540);
    expect(schedule.hours.isOpenOn(DateTime(2030, 1, 2)), isFalse, reason: 'Wednesday closed');
    expect(schedule.busy.single.minutes, 120);
  });
}
