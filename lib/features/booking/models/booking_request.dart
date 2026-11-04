import '../../community/models/models.dart';

/// Everything the customer chose while booking, before it becomes a real
/// booking. The customer first pays the deposit (15% of the service cost);
/// the service cost itself is paid after the provider accepts.
class BookingRequest {
  final String providerId;
  final String providerName;
  final String serviceId;
  final String serviceName;
  final int hourlyRate;
  final int hours;

  /// Set when the customer chose a package ([hourlyRate] then holds the package price).
  final String? packageName;
  final String date;
  final String time;
  final String address;

  /// The customer's spot on the map (optional).
  final double? latitude;
  final double? longitude;
  final String notes;

  const BookingRequest({
    required this.providerId,
    required this.providerName,
    required this.serviceId,
    required this.serviceName,
    required this.hourlyRate,
    required this.hours,
    this.packageName,
    required this.date,
    required this.time,
    required this.address,
    this.latitude,
    this.longitude,
    this.notes = '',
  });

  /// Service cost: rate x hours, or the package price (what the provider earns).
  int get serviceTotal => hourlyRate * hours;

  /// Deposit paid now.
  int get fee => bookingFeeFor(serviceTotal);
}
