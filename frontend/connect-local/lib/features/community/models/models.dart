import 'package:flutter/foundation.dart';

import '../../shared/photo.dart';
import 'schedule.dart';

export 'schedule.dart';

/// The deposit the customer pays when sending a request: 15% of the
/// service cost. It is separate from what the provider earns.
const double kBookingFeeRate = 0.15;

int bookingFeeFor(int serviceTotal) => (serviceTotal * kBookingFeeRate).round();

/// ConnectLocal's cut of each job (taken from the provider's payout). The admin
/// can change it; this is the starting value.
const double kDefaultCommissionRate = 0.10;

/// How a payment is made. Cards go through PayFast; cash is handed to the provider.
enum PayMethod {
  card('Card (PayFast)'),
  instantEft('Instant EFT (PayFast)'),
  applePay('Apple Pay (PayFast)'),
  samsungPay('Samsung Pay (PayFast)'),
  capitecPay('Capitec Pay (PayFast)'),
  scanToPay('Scan to Pay (PayFast)'),
  mobicred('Mobicred (PayFast)'),
  cash('Cash');

  final String label;
  const PayMethod(this.label);

  /// Paid online through PayFast (everything except cash).
  bool get isOnline => this != PayMethod.cash;
}

enum PaymentKind {
  bookingFee('Deposit'),
  service('Service payment');

  final String label;
  const PaymentKind(this.label);
}

enum PaymentStatus {
  /// Cash promised but not yet confirmed by the provider.
  pending('Pending'),
  paid('Paid'),

  /// Card payment for the service: held by ConnectLocal until the customer's
  /// PIN proves the job was done.
  held('Held by ConnectLocal'),

  /// Held payment released to the provider after the PIN was entered.
  released('Released to provider'),
  refunded('Refunded');

  final String label;
  const PaymentStatus(this.label);
}

/// One recorded payment (kept for receipts and so each transaction can be
/// checked later). TODO (backend): store these server-side.
class PaymentRecord {
  final String id;
  final String bookingId;
  final PaymentKind kind;
  final PayMethod method;
  final int amount;
  final DateTime createdAt;

  /// PayFast's own payment id (pf_payment_id); null for cash.
  final String? gatewayReference;

  PaymentStatus status;

  /// True when the payment was confirmed: for card by PayFast's server
  /// notification (ITN), for cash by the provider handing over the PIN check.
  bool verified;

  PaymentRecord({
    required this.id,
    required this.bookingId,
    required this.kind,
    required this.method,
    required this.amount,
    required this.createdAt,
    this.gatewayReference,
    this.status = PaymentStatus.paid,
    this.verified = false,
  });
}

enum BookingStatus {
  pending('Pending'),
  confirmed('Confirmed'),
  completed('Completed'),
  declined('Declined'),
  cancelled('Cancelled');

  final String label;
  const BookingStatus(this.label);
}

/// The detailed step a booking is at (what people see on cards and in admin).
enum BookingStage {
  awaitingProvider('Awaiting provider'),
  secured('Booking secured'),
  inProgress('In progress'),
  paymentDue('Payment due'),
  cashPending('Cash payment pending'),
  completed('Completed'),
  declined('Declined'),
  cancelled('Cancelled');

  final String label;
  const BookingStage(this.label);
}

@immutable
class ChatMessage {
  final String text;
  final DateTime sentAt;
  final bool fromProvider;

  const ChatMessage({
    required this.text,
    required this.sentAt,
    required this.fromProvider,
  });
}

/// One option a customer can choose for a service, e.g. "Install 1 CCTV camera"
/// or "Install 3 CCTV cameras", each with its own fixed price.
class ServicePackage {
  String name;
  int price;
  String description;

  ServicePackage({required this.name, required this.price, this.description = ''});
}

/// How a service is charged. Different kinds of business charge differently:
/// a plumber per hour, a salon a fixed price per treatment, a CCTV installer
/// by package (1 camera / 3 cameras ...).
enum PricingType { hourly, fixed, packages }

class ServiceModel {
  final String id;
  String name;
  String category;
  int price;
  String description;
  List<PhotoRef> photos;
  double? rating;
  bool active;

  /// Fixed-price options. When empty the service is priced per hour ([price]).
  /// When there are packages, [price] holds the cheapest one ("From R...").
  List<ServicePackage> packages;

  /// Per hour, one fixed price, or packages. For packages [price] is the cheapest.
  PricingType pricingType;

  /// Package name -> server id (so edits update the right package). Empty for device-only services.
  final Map<String, String> serverPackageIds = {};

  ServiceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.description = '',
    List<PhotoRef>? photos,
    this.rating,
    this.active = true,
    List<ServicePackage>? packages,
    PricingType? pricingType,
  })  : photos = photos ?? [],
        packages = packages ?? [],
        pricingType = pricingType ??
            ((packages != null && packages.isNotEmpty)
                ? PricingType.packages
                : PricingType.hourly);

  int get photoCount => photos.length;

  bool get hasPackages => pricingType == PricingType.packages && packages.isNotEmpty;

  bool get isFixedPrice => pricingType == PricingType.fixed;

  /// "R350/hour", "R150" (fixed) or "From R1200" (packages) – used everywhere a price is listed.
  String get priceLabel => hasPackages
      ? 'From R$price'
      : isFixedPrice
          ? 'R$price'
          : 'R$price/hour';
}

class ProviderModel {
  final String id;
  String name;
  double rating;
  int reviews;

  /// Distance from the customer in km. Starts as a sample value and is
  /// replaced by the real GPS distance once the customer's location is known
  /// (see [distanceIsLive]).
  double distanceKm;

  /// True when [distanceKm] was calculated from the customer's real position.
  bool distanceIsLive;

  /// The business's profile picture (logo or portrait).
  PhotoRef? avatar;

  /// Where the provider works. TODO (DB): load from the backend / geocode the
  /// address the provider entered.
  double? latitude;
  double? longitude;

  /// The business address as the provider typed it (street, suburb, city).
  String address;

  /// Booking options the provider offers (chosen in their business profile):
  /// customers come to the business / salon, and/or the provider comes to the customer.
  bool offersVisit;
  bool offersHouseCall;

  /// Days and hours the provider works, and how long one booking slot is.
  WorkingHours workingHours;
  final List<ServiceModel> services;

  /// True once the admin has checked the business's registration number and
  /// documents ("Verified business" badge).
  bool verified;

  ProviderModel({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviews,
    required this.distanceKm,
    required this.services,
    this.latitude,
    this.longitude,
    this.address = '',
    this.offersVisit = false,
    this.offersHouseCall = true,
    this.workingHours = WorkingHours.standard,
    this.distanceIsLive = false,
    this.verified = false,
  });

  /// True when the business has a place customers can find (a map pin or an address).
  bool get hasBusinessLocation => (latitude != null && longitude != null) || address.trim().isNotEmpty;

  /// "Visit the business" is only offered when the provider allows it AND the place can be found.
  bool get canBeVisited => offersVisit && hasBusinessLocation;

  /// The picture to show for this provider in lists: their own profile
  /// picture, else the first photo of any of their active services.
  PhotoRef? get displayPhoto {
    if (avatar != null) return avatar;
    for (final service in services) {
      if (service.active && service.photos.isNotEmpty) return service.photos.first;
    }
    return null;
  }

  /// Every photo from this provider's active services (their portfolio).
  List<PhotoRef> get portfolio => [
        for (final service in services)
          if (service.active) ...service.photos,
      ];

  List<ServiceModel> get activeServices =>
      services.where((service) => service.active).toList(growable: false);
}

class Booking {
  final String id;
  final String providerId;
  final String serviceId;
  final String serviceName;
  String clientName;
  final DateTime dateTime;

  /// Number of hours booked (1 for a package).
  final int hours;

  /// The package the customer chose (null for a per-hour booking).
  final String? packageName;

  /// Service cost for all hours (rate x hours). This is what the provider
  /// earns; the deposit is not included.
  final int price;

  /// Deposit (15% of [price]) paid by the customer with the request.
  final int bookingFee;

  /// True once the customer has paid the [price] (after the provider accepted).
  bool balancePaid;

  /// True when the deposit was given back (declined / cancelled early).
  bool feeRefunded;

  /// Customer's review after the job is completed.
  int? rating;
  String? review;

  /// How the customer chose to pay the service cost (null until they choose).
  PayMethod? serviceMethod;

  /// Unique 4-digit PIN created when the provider accepts. The customer reads
  /// it out when the job is done; the provider enters it to complete the job.
  String? completionPin;
  int pinAttempts = 0;

  /// True once the provider entered the correct PIN (proof of service).
  bool pinVerified = false;

  /// Where the customer is (picked on the map). Null when only a typed address exists.
  double? latitude;
  double? longitude;

  final double distanceKm;
  final String phone;

  /// True = the customer visits the business / salon. False = house call: the provider comes to
  /// [address] (the customer's home or current location).
  final bool atBusiness;

  /// How long this booking holds the provider's time from [dateTime]: one slot, or the hours booked
  /// for a per-hour service. Other customers cannot book an overlapping slot while it is active.
  final int blockedMinutes;

  /// House call: where the provider must go. Empty for a business visit.
  final String address;
  final String notes;
  BookingStatus status;

  Booking({
    required this.id,
    required this.providerId,
    required this.serviceId,
    required this.serviceName,
    required this.clientName,
    required this.dateTime,
    required this.price,
    this.hours = 1,
    this.packageName,
    int? bookingFee,
    this.balancePaid = false,
    this.feeRefunded = false,
    this.rating,
    this.review,
    this.serviceMethod,
    this.completionPin,
    this.distanceKm = 0,
    this.phone = '',
    this.atBusiness = false,
    this.blockedMinutes = 60,
    this.address = '',
    this.notes = '',
    this.status = BookingStatus.pending,
  }) : bookingFee = bookingFee ?? bookingFeeFor(price);

  /// Still holding the provider's time slot (requested or accepted, not finished / declined / cancelled).
  bool get holdsSlot => status == BookingStatus.pending || status == BookingStatus.confirmed;

  /// "Visit the business" or "House call" (shown on booking cards and details).
  String get locationTypeLabel => atBusiness ? 'Visit the business' : 'House call';

  /// What the customer pays in total. The 15% deposit counts
  /// toward the price, so the total is just [price].
  int get customerTotal => price;

  /// What is still to pay after the job: the price minus the deposit.
  int get balance => price > bookingFee ? price - bookingFee : 0;

  /// "Install 3 CCTV cameras" or "2 hours".
  String get quantityLabel => packageName ?? (hours == 1 ? '1 hour' : '$hours hours');

  /// The job is done but the customer has not paid the service cost yet.
  bool get awaitingPayment => status == BookingStatus.completed && !balancePaid;

  /// Still going on: not yet finished AND paid (shown under "Upcoming").
  bool get isActive =>
      status == BookingStatus.pending ||
      status == BookingStatus.confirmed ||
      awaitingPayment;

  /// Where this booking is right now, in plain words.
  BookingStage get stage {
    switch (status) {
      case BookingStatus.pending:
        return BookingStage.awaitingProvider;
      case BookingStatus.confirmed:
        return pinVerified ? BookingStage.inProgress : BookingStage.secured;
      case BookingStatus.completed:
        if (balancePaid) return BookingStage.completed;
        return serviceMethod == PayMethod.cash
            ? BookingStage.cashPending
            : BookingStage.paymentDue;
      case BookingStatus.declined:
        return BookingStage.declined;
      case BookingStatus.cancelled:
        return BookingStage.cancelled;
    }
  }
}

enum ApplicationStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  final String label;
  const ApplicationStatus(this.label);
}

/// A "Become a Provider" application waiting for (or past) admin review.
class ProviderApplicationRecord {
  final String id;
  final String businessName;
  final String email;
  final String services;
  final String description;
  final String location;
  final DateTime appliedAt;

  /// Company / business registration number (e.g. 2019/123456/07).
  final String registrationNumber;

  /// Photo or scan of the registration certificate.
  final PhotoRef? registrationDoc;

  /// Applicant's South African ID number (checked with the ID checksum) and a
  /// photo of the ID document, for the admin to compare.
  final String idNumber;
  final PhotoRef? idDoc;

  /// Name of the person who applied (used to notify them).
  final String applicantName;

  /// Where the business works (found from the address or the phone's GPS).
  final double? latitude;
  final double? longitude;

  /// Portfolio photos the applicant added.
  final List<PhotoRef> photos;

  /// True when this application was submitted by the person using the app
  /// (so they get a notification when the admin decides).
  final bool mine;
  ApplicationStatus status;

  /// Why the admin rejected it (shown to the applicant).
  String? rejectionReason;

  ProviderApplicationRecord({
    required this.id,
    required this.businessName,
    required this.email,
    required this.services,
    required this.appliedAt,
    this.description = '',
    this.location = '',
    this.registrationNumber = '',
    this.registrationDoc,
    this.idNumber = '',
    this.idDoc,
    this.applicantName = '',
    this.latitude,
    this.longitude,
    this.photos = const [],
    this.mine = false,
    this.status = ApplicationStatus.pending,
  });

  /// "just now", "5 minutes ago", "2 days ago", "1 week ago"...
  String get appliedLabel {
    final diff = DateTime.now().difference(appliedAt);
    String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return plural(diff.inMinutes, 'minute');
    if (diff.inHours < 24) return plural(diff.inHours, 'hour');
    if (diff.inDays < 7) return plural(diff.inDays, 'day');
    return plural(diff.inDays ~/ 7, 'week');
  }
}


/// Where a provider's earnings are paid (their bank account). TODO (backend):
/// store this server-side, encrypted, and never return the full number to apps.
class PayoutAccount {
  String bank;
  String accountType;
  String holderName;
  String accountNumber;
  String branchCode;

  PayoutAccount({
    required this.bank,
    required this.accountType,
    required this.holderName,
    required this.accountNumber,
    required this.branchCode,
  });

  /// "•••• 1234" – what the provider sees after saving.
  String get masked => accountNumber.length <= 4
      ? accountNumber
      : '\u2022\u2022\u2022\u2022 ${accountNumber.substring(accountNumber.length - 4)}';
}

enum PayoutStatus {
  due('Payout due'),
  paid('Paid');

  final String label;
  const PayoutStatus(this.label);
}

/// Money ConnectLocal owes a provider for one finished job (the service cost
/// of a card payment that was released by the PIN). Cash jobs have no payout:
/// the provider already holds the cash.
class Payout {
  final String id;
  final String providerId;
  final String bookingId;
  final String serviceName;
  final String clientName;
  /// What the provider receives (job total minus ConnectLocal's commission).
  final int amount;

  /// The full price of the job and ConnectLocal's commission on it.
  final int jobTotal;
  final int commission;
  final DateTime createdAt;
  PayoutStatus status;
  DateTime? paidAt;

  /// The EFT reference the admin entered when paying.
  String? reference;

  Payout({
    required this.id,
    required this.providerId,
    required this.bookingId,
    required this.serviceName,
    required this.clientName,
    required this.amount,
    int? jobTotal,
    this.commission = 0,
    required this.createdAt,
    this.status = PayoutStatus.due,
    this.paidAt,
    this.reference,
  }) : jobTotal = jobTotal ?? amount + commission;
}


/// A person's sign-in account (customer, and provider once approved).
/// The password is stored only as a salted hash. TODO (backend): replaced by
/// Supabase Auth; this class then only holds the profile fields.
class UserAccount {
  String name;
  final String email;
  final String salt;
  final String passwordHash;
  final DateTime createdAt;
  bool emailVerified;
  String phone;
  String? verifiedPhone;
  String address;

  /// Admin switch: a disabled account can't sign in.
  bool disabled;

  UserAccount({
    required this.name,
    required this.email,
    required this.salt,
    required this.passwordHash,
    required this.createdAt,
    this.emailVerified = false,
    this.phone = '',
    this.verifiedPhone,
    this.address = '',
    this.disabled = false,
  });
}
