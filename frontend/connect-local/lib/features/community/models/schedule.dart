/// Working hours and booking time slots.
///
/// A provider sets the days and hours they work and how long one slot is (30 min ... full day).
/// Customers book a slot at a specific start time. While a booking is active (requested or accepted),
/// the time it covers is taken: no other customer can book an overlapping slot with that provider.
library;

/// Minutes kept free after every booking, so a job that runs a little long (or travel to the next
/// customer) does not run into the next booking. Applies to every provider; nothing to set.
const int kBookingGapMinutes = 30;

/// Slot lengths a provider can choose (minutes).
const List<int> kSlotLengths = [30, 60, 120, 240, 480];

/// 30 -> "30 minutes", 60 -> "1 hour", 240 -> "Half day (4 hours)", 480 -> "Full day (8 hours)".
String slotLengthLabel(int minutes) => switch (minutes) {
      30 => '30 minutes',
      60 => '1 hour',
      240 => 'Half day (4 hours)',
      480 => 'Full day (8 hours)',
      _ => minutes % 60 == 0 ? '${minutes ~/ 60} hours' : '$minutes minutes',
    };

/// "8:00 AM"-style label for minutes since midnight.
String clockLabel(int minutesOfDay) {
  final h24 = minutesOfDay ~/ 60;
  final m = minutesOfDay % 60;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h24 < 12 ? 'AM' : 'PM'}';
}

/// The opening hours of one day, in minutes since midnight (e.g. 8:00 = 480).
class DayHours {
  final int open;
  final int close;
  const DayHours(this.open, this.close) : assert(close > open);

  Map<String, int> toJson() => {'open': open, 'close': close};
}

/// Day names, Monday first (index 0 = DateTime.monday).
const List<String> kWeekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

class WorkingHours {
  /// Open days: DateTime.monday (1) ... DateTime.sunday (7). A missing day is closed.
  final Map<int, DayHours> days;

  /// How long one booking slot is, in minutes (one of [kSlotLengths]).
  final int slotMinutes;

  const WorkingHours({required this.days, this.slotMinutes = 60});

  /// Used until the provider sets their own: Monday-Friday 8:00-17:00, Saturday 9:00-13:00, 1-hour slots.
  static const WorkingHours standard = WorkingHours(days: {
    DateTime.monday: DayHours(480, 1020),
    DateTime.tuesday: DayHours(480, 1020),
    DateTime.wednesday: DayHours(480, 1020),
    DateTime.thursday: DayHours(480, 1020),
    DateTime.friday: DayHours(480, 1020),
    DateTime.saturday: DayHours(540, 780),
  });

  bool get isClosedEveryDay => days.isEmpty;

  bool isOpenOn(DateTime day) => days.containsKey(day.weekday);

  /// Start times of all slots on [day], whether taken or not. Every slot fits before closing time.
  List<DateTime> slotStarts(DateTime day) {
    final hours = days[day.weekday];
    if (hours == null) return const [];
    return [
      for (var start = hours.open; start + slotMinutes <= hours.close; start += slotMinutes)
        DateTime(day.year, day.month, day.day, start ~/ 60, start % 60),
    ];
  }

  /// True when a booking of [minutes] starting at [start] ends by closing time that day.
  bool fitsInDay(DateTime start, int minutes) {
    final hours = days[start.weekday];
    if (hours == null) return false;
    final from = start.hour * 60 + start.minute;
    return from >= hours.open && from + minutes <= hours.close;
  }

  Map<String, dynamic> toJson() => {
        'slotMinutes': slotMinutes,
        'days': {for (final e in days.entries) '${e.key}': e.value.toJson()},
      };

  static WorkingHours fromJson(dynamic json) {
    if (json is! Map) return standard;
    final days = <int, DayHours>{};
    final raw = json['days'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final day = int.tryParse('${e.key}');
        final v = e.value;
        if (day == null || day < 1 || day > 7 || v is! Map) continue;
        final open = v['open'];
        final close = v['close'];
        if (open is int && close is int && close > open) days[day] = DayHours(open, close);
      }
    }
    final slot = json['slotMinutes'];
    return WorkingHours(days: days, slotMinutes: slot is int && slot > 0 ? slot : 60);
  }
}

/// True when [aStart, aStart + aMinutes) and [bStart, bStart + bMinutes) overlap.
bool timesOverlap(DateTime aStart, int aMinutes, DateTime bStart, int bMinutes) {
  final aEnd = aStart.add(Duration(minutes: aMinutes));
  final bEnd = bStart.add(Duration(minutes: bMinutes));
  return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
}
