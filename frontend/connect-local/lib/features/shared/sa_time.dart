/// Booking times are South African time (SAST = UTC+2 all year, no daylight saving), whatever time zone the
/// phone or laptop is set to. Inside the app a booking/slot time is an SAST "wall clock" DateTime (its hour
/// is the SAST hour); it is turned into a real instant only when sent to the server.
library;

const _sastOffset = Duration(hours: 2);

/// An instant (e.g. from the server) as an SAST wall-clock time.
DateTime sastWall(DateTime instant) {
  final u = instant.toUtc().add(_sastOffset);
  return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

/// An SAST wall-clock time as the real instant (UTC) to send to the server.
DateTime sastWallToUtc(DateTime wall) =>
    DateTime.utc(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second).subtract(_sastOffset);

/// "Now" in South Africa.
DateTime nowSast() => sastWall(DateTime.now());
