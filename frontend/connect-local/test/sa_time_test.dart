import 'package:connect_local/features/shared/sa_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a slot shown as 16:00 (SAST) is sent as 14:00 UTC, whatever the phone time zone', () {
    final slot = DateTime(2030, 1, 2, 16); // SAST wall clock, as the booking screen builds it
    expect(sastWallToUtc(slot).toIso8601String(), '2030-01-02T14:00:00.000Z');
  });

  test('a server time is shown in SAST', () {
    final wall = sastWall(DateTime.parse('2030-01-02T22:30:00Z'));
    expect([wall.year, wall.month, wall.day, wall.hour, wall.minute], [2030, 1, 3, 0, 30]); // next day 00:30
  });

  test('round trip', () {
    final wall = DateTime(2030, 6, 15, 8, 45);
    expect(sastWall(sastWallToUtc(wall)), wall);
  });
}
