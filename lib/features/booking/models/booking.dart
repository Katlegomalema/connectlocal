// Simple model used by My Bookings / Booking Detail.
// Teammate can map database rows to this.
class Booking {
  final String id;
  final String provider;
  final String service;
  final String date;
  final String time;
  final String total;
  final String status; // Pending, Confirmed, Completed

  const Booking({
    required this.id,
    required this.provider,
    required this.service,
    required this.date,
    required this.time,
    required this.total,
    required this.status,
  });
}