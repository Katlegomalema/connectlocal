import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/photo.dart';
import '../models/models.dart';

part 'app_state_storage.dart';

enum LocationStatus {
  /// Not asked yet (or switched off in Settings).
  unknown,
  loading,
  ready,

  /// The phone's location (GPS) switch is off.
  serviceOff,

  /// The user said no to the permission prompt (we can ask again).
  denied,

  /// The user chose "don't ask again" (only the system settings can undo it).
  deniedForever,
  error,
}

/// Result of the provider entering the customer's PIN when they arrive.
enum PinResult { ok, wrong, locked, notAllowed }

/// After this many wrong PINs the job is locked (protects against guessing).
const int kMaxPinAttempts = 5;

class AppState extends ChangeNotifier {
  static const categories = <String>[
    'Home Repair',
    'Cleaning',
    'Beauty',
    'Tutoring',
    'Gardening',
    'Security',
  ];

  String customerName = '';
  String customerEmail = '';
  String customerPhone = '';

  /// The customer's own profile picture (null = show the default icon).
  /// TODO (backend): upload it and keep the returned URL.
  PhotoRef? customerPhoto;

  /// The customer's verified mobile number (e.g. "+27 82 123 4567"), or null.
  String? verifiedPhone;

  /// True once the customer's email address was confirmed (sign-up link or Google).
  bool emailVerified = false;

  /// A genuine client: confirmed email AND confirmed phone number.
  bool get isClientVerified => emailVerified && verifiedPhone != null;

  /// True for an approved provider (Provider mode is only offered to them).
  /// Set at sign-in from the backend, or when the admin approves your application.
  bool isProvider = false;

  /// True when the person chose "I offer a service" on the Register screen.
  /// After their first sign-in they land on the provider onboarding screen
  /// instead of the customer Home. (Not saved: it only lives until sign-in.)
  bool providerSignupIntent = false;

  /// Reads the Register choice once, then forgets it.
  bool takeProviderSignupIntent() {
    final value = providerSignupIntent;
    providerSignupIntent = false;
    return value;
  }
  String customerAddress = '';
  String businessDescription = '';
  String businessLocation = '';
  /// Shown only while the signed-in person owns no business yet (never listed).
  final ProviderModel _noProvider = ProviderModel(
    id: 'provider-none',
    name: 'Your business',
    rating: 0,
    reviews: 0,
    distanceKm: 0,
    services: [],
  );

  /// Every business on the platform. Starts empty: businesses appear when the
  /// admin approves a provider's application.
  final List<ProviderModel> providers = [];

  // ---- Customer location (real GPS distance to providers) ----------------

  /// The "Location services" switch in Settings.
  bool locationEnabled = true;
  LocationStatus locationStatus = LocationStatus.unknown;
  double? userLatitude;
  double? userLongitude;
  bool _disposed = false;

  // Saving on this device (see app_state_storage.dart).
  Timer? _saveTimer;
  bool _persist = false;

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
    if (_persist) {
      // Save shortly after the last change (one write for a burst of changes).
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 400), _writeNow);
    }
  }

  Future<void> setLocationEnabled(bool value) {
    locationEnabled = value;
    return refreshLocation();
  }

  /// Asks for permission (if needed), reads the phone's GPS position and
  /// recalculates every provider's distance. Safe to call repeatedly.
  Future<void> refreshLocation() async {
    if (!locationEnabled) {
      _clearLiveDistances();
      locationStatus = LocationStatus.unknown;
      notifyListeners();
      return;
    }
    if (locationStatus == LocationStatus.loading) return;
    locationStatus = LocationStatus.loading;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        locationStatus = LocationStatus.serviceOff;
        notifyListeners();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        locationStatus = LocationStatus.deniedForever;
        notifyListeners();
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        locationStatus = LocationStatus.denied;
        notifyListeners();
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      userLatitude = position.latitude;
      userLongitude = position.longitude;
      _updateDistances();
      locationStatus = LocationStatus.ready;
    } catch (_) {
      // Timeout, no signal, browser blocked it, etc.
      locationStatus = LocationStatus.error;
    }
    notifyListeners();
  }

  /// Opens the phone's settings so the user can fix a location problem.
  /// (Not available in a browser; there the user uses the address-bar lock icon.)
  Future<void> openLocationHelp() async {
    try {
      if (locationStatus == LocationStatus.serviceOff) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (_) {}
  }

  void _updateDistances() {
    final lat = userLatitude;
    final lng = userLongitude;
    if (lat == null || lng == null) return;
    for (final p in providers) {
      final pLat = p.latitude;
      final pLng = p.longitude;
      if (pLat == null || pLng == null) continue;
      // Straight-line distance (not driving distance).
      p.distanceKm = Geolocator.distanceBetween(lat, lng, pLat, pLng) / 1000;
      p.distanceIsLive = true;
    }
  }

  void _clearLiveDistances() {
    for (final p in providers) {
      p.distanceIsLive = false;
    }
    userLatitude = null;
    userLongitude = null;
  }

  final List<Booking> _bookings = [];
  final Map<String, List<ChatMessage>> _chats = {};
  final Map<String, List<String>> _providerNotes = {};
  final Map<String, int> _providerUnread = {};

  /// Notifications of the provider whose dashboard is open.
  List<String> get notifications =>
      List.unmodifiable(_providerNotes[activeProvider.id] ?? const <String>[]);
  int get unreadNotifications => _providerUnread[activeProvider.id] ?? 0;

  void _notifyProvider(String providerId, String text) {
    _providerNotes.putIfAbsent(providerId, () => []).insert(0, text);
    _providerUnread[providerId] = (_providerUnread[providerId] ?? 0) + 1;
  }

  /// The customer's own notifications (kept separate from the provider's above).
  final Map<String, List<String>> _customerNotes = {};
  final Map<String, int> _customerUnread = {};
  List<String> get customerNotifications =>
      List.unmodifiable(_customerNotes[customerName] ?? const <String>[]);
  int get unreadCustomerNotifications => _customerUnread[customerName] ?? 0;

  /// Tell the customer called [name] something (they see it when they log in).
  void _notifyCustomer(String name, String text) {
    _customerNotes.putIfAbsent(name, () => []).insert(0, text);
    _customerUnread[name] = (_customerUnread[name] ?? 0) + 1;
  }

  void markCustomerNotificationsRead() {
    _customerUnread[customerName] = 0;
    notifyListeners();
  }

  // TODO (DB): load provider applications from the backend.
  final List<ProviderApplicationRecord> providerApplications = [];

  List<ProviderApplicationRecord> applicationsWithStatus(ApplicationStatus status) =>
      providerApplications.where((a) => a.status == status).toList();

  /// The latest application sent by the person using the app (or null).
  ProviderApplicationRecord? get myApplication {
    final e = customerEmail.trim().toLowerCase();
    for (final a in providerApplications) {
      if (a.mine && a.email.trim().toLowerCase() == e) return a;
    }
    return null;
  }

  /// True if a pending or approved application already uses this registration
  /// number (one business can't be registered twice).
  bool registrationNumberTaken(String number) => providerApplications.any((a) =>
      a.registrationNumber == number.trim() && a.status != ApplicationStatus.rejected);

  /// Called by the "Become a Provider" form. The application shows up in the
  /// admin's Pending list straight away.
  void submitProviderApplication({
    required String businessName,
    required String category,
    required String description,
    required String location,
    String registrationNumber = '',
    PhotoRef? registrationDoc,
    double? latitude,
    double? longitude,
    String idNumber = '',
    PhotoRef? idDoc,
    List<PhotoRef> photos = const [],
  }) {
    providerApplications.insert(
      0,
      ProviderApplicationRecord(
        id: 'application-${DateTime.now().microsecondsSinceEpoch}',
        registrationNumber: registrationNumber,
        registrationDoc: registrationDoc,
        idNumber: idNumber,
        idDoc: idDoc,
        applicantName: customerName,
        latitude: latitude,
        longitude: longitude,
        businessName: businessName,
        email: customerEmail,
        services: category,
        description: description,
        location: location,
        photos: List.unmodifiable(photos),
        appliedAt: DateTime.now(),
        mine: true,
      ),
    );
    notifyListeners();
  }

  /// Called by Login with what the backend returned.
  void signIn({
    required String name,
    required String email,
    required bool isProvider,
    bool emailVerified = true,
    String? providerId,
  }) {
    _syncAccount();
    final account = accountByEmail(email);
    this.emailVerified = account?.emailVerified ?? emailVerified;
    customerPhone = account?.phone ?? '';
    verifiedPhone = account?.verifiedPhone;
    customerAddress = account?.address ?? '';
    customerName = name.trim().isNotEmpty ? name.trim() : customerName;
    customerEmail = email;
    // Provider mode for people whose application the admin approved.
    this.isProvider = isProvider || providerOwnedBy(email) != null;
    final owned = providerOwnedBy(email);
    if (owned != null) {
      businessLocation = businessLocation.isEmpty ? customerAddress : businessLocation;
    }
    notifyListeners();
  }

  // ---- accounts -----------------------------------------------------------
  final List<UserAccount> accounts = [];

  UserAccount? accountByEmail(String email) {
    final e = email.trim().toLowerCase();
    for (final a in accounts) {
      if (a.email == e) return a;
    }
    return null;
  }

  String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  /// Creates an account. Returns an error message, or null when it worked.
  String? registerAccount({required String name, required String email, required String password}) {
    final e = email.trim().toLowerCase();
    if (accountByEmail(e) != null) return 'An account with this email already exists. Please log in.';
    // Bookings and notifications are matched by name in this prototype, so
    // two people can't share a name. TODO (backend): matched by user id.
    final n = name.trim().toLowerCase();
    if (accounts.any((a) => a.name.trim().toLowerCase() == n)) {
      return 'Someone is already registered with this name. Add a middle initial or surname detail.';
    }
    final r = Random.secure();
    final salt = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    accounts.add(UserAccount(
      name: name.trim(),
      email: e,
      salt: salt,
      passwordHash: _hash(salt, password),
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    return null;
  }

  /// Checks an email + password. Throws a readable message when wrong.
  UserAccount authenticate(String email, String password) {
    final account = accountByEmail(email);
    if (account == null || account.passwordHash != _hash(account.salt, password)) {
      throw StateError('Wrong email or password.');
    }
    if (account.disabled) {
      throw StateError('This account has been disabled. Please contact support.');
    }
    return account;
  }

  /// Marks the email as confirmed (stand-in for clicking the link in the e-mail).
  void verifyEmailFor(String email) {
    final account = accountByEmail(email);
    if (account == null) return;
    account.emailVerified = true;
    if (customerEmail.trim().toLowerCase() == account.email) emailVerified = true;
    notifyListeners();
  }

  void setAccountDisabled(UserAccount account, bool disabled) {
    account.disabled = disabled;
    notifyListeners();
  }

  /// Copies the profile fields of the person using the app back to their account.
  void _syncAccount() {
    final account = accountByEmail(customerEmail);
    if (account == null) return;
    account.name = customerName.isEmpty ? account.name : customerName;
    account.phone = customerPhone;
    account.verifiedPhone = verifiedPhone;
    account.address = customerAddress;
    account.emailVerified = emailVerified;
  }

  /// Admin approves or rejects an application.
  void setApplicationStatus(ProviderApplicationRecord application, ApplicationStatus status,
      {String? reason}) {
    application.status = status;
    application.rejectionReason = reason;
    if (application.mine && status == ApplicationStatus.approved &&
        providerOwnedBy(application.email) == null) {
      // The business goes live: a real provider owned by the applicant. It
      // appears in other customers' search as soon as it has a service.
      final provider = ProviderModel(
        id: 'provider-app-${DateTime.now().microsecondsSinceEpoch}',
        name: application.businessName,
        rating: 0,
        reviews: 0,
        distanceKm: 5,
        latitude: application.latitude,
        longitude: application.longitude,
        services: [],
        verified: true, // the admin checked the registration number and documents
      );
      providers.add(provider);
      _updateDistances();
      _providerOwner[provider.id] = application.email.trim().toLowerCase();
      businessDescription = application.description;
      businessLocation = application.location;
      if (customerEmail.trim().toLowerCase() == application.email.trim().toLowerCase()) {
        isProvider = true;
      }
    }
    if (application.mine) {
      _notifyCustomer(
        application.applicantName,
        status == ApplicationStatus.approved
            ? 'Great news! ${application.businessName} was approved and verified. '
                'Open Provider mode, then add your services and prices under Services to start getting bookings.'
            : 'Your provider application for ${application.businessName} was '
                '${status.label.toLowerCase()}.'
                '${reason == null || reason.isEmpty ? '' : ' Reason: $reason'} You can apply again with the right details.',
      );
    }
    notifyListeners();
  }
  int _nextBookingNumber = 1;
  int _nextServiceNumber = 3;

  AppState();

  List<ProviderModel> search({
    String query = '',
    String category = 'ALL',
    bool nearestFirst = false,
  }) {
    final q = query.trim().toLowerCase();
    final matches = providers.where((provider) {
      final active = provider.activeServices;
      final categoryMatch = category == 'ALL' ||
          active.any((service) => service.category.toLowerCase() == category.toLowerCase());
      final textMatch = q.isEmpty ||
          provider.name.toLowerCase().contains(q) ||
          active.any((service) =>
              service.name.toLowerCase().contains(q) ||
              service.category.toLowerCase().contains(q) ||
              service.description.toLowerCase().contains(q));
      // Your own business never shows up in your customer search.
      return _providerOwner[provider.id] != customerEmail.trim().toLowerCase() &&
          categoryMatch && textMatch && active.isNotEmpty;
    }).toList();
    if (nearestFirst && locationStatus == LocationStatus.ready) {
      matches.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } else {
      matches.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return matches;
  }

  ProviderModel providerById(String id) => providers.firstWhere(
        (provider) => provider.id == id,
        orElse: () => _noProvider,
      );

  List<Booking> get customerBookings => _bookings
      .where((booking) => booking.clientName == customerName)
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  /// providerId -> e-mail of the person who owns that business (created when the
  /// admin approves their application).
  final Map<String, String> _providerOwner = {};
  ProviderModel? providerOwnedBy(String email) {
    final e = email.trim().toLowerCase();
    for (final p in providers) {
      if (_providerOwner[p.id] == e) return p;
    }
    return null;
  }

  ProviderModel get activeProvider => providerOwnedBy(customerEmail) ?? _noProvider;
  /// Every booking on the platform (admin view).
  List<Booking> get allBookings => List.unmodifiable(
      _bookings.toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime)));

  List<Booking> get providerBookings => _bookings
      .where((booking) => booking.providerId == activeProvider.id)
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  List<Booking> get todayBookings {
    final now = DateUtils.dateOnly(DateTime.now());
    return providerBookings.where((booking) =>
        DateUtils.dateOnly(booking.dateTime) == now).toList();
  }

  int get pendingCount => providerBookings
      .where((booking) => booking.status == BookingStatus.pending)
      .length;

  int get totalEarned => providerBookings
      .where((booking) => booking.status == BookingStatus.completed)
      .fold(0, (sum, booking) => sum + booking.price);

  List<ChatMessage> chatFor(String bookingId) =>
      List.unmodifiable(_chats[bookingId] ?? const <ChatMessage>[]);

  void sendMessage(String bookingId, String text, {required bool fromProvider}) {
    final messages = _chats.putIfAbsent(bookingId, () => <ChatMessage>[]);
    messages.add(ChatMessage(
      text: text,
      sentAt: DateTime.now(),
      fromProvider: fromProvider,
    ));
    notifyListeners();
  }

  void updateBusinessProfile({
    required String name,
    required String description,
    required String location,
    double? latitude,
    double? longitude,
  }) {
    if (latitude != null && longitude != null) {
      activeProvider.latitude = latitude;
      activeProvider.longitude = longitude;
      _updateDistances();
    }
    if (name.trim().isNotEmpty) activeProvider.name = name.trim();
    businessDescription = description.trim();
    businessLocation = location.trim();
    notifyListeners();
  }

  void markNotificationsRead() {
    _providerUnread[activeProvider.id] = 0;
    notifyListeners();
  }

  void setVerifiedPhone(String? number) {
    verifiedPhone = number;
    notifyListeners();
  }

  void setCustomerPhoto(PhotoRef? photo) {
    customerPhoto = photo;
    notifyListeners();
  }

  void setBusinessPhoto(PhotoRef? photo) {
    activeProvider.avatar = photo;
    notifyListeners();
  }

  void updateCustomerProfile({required String name, required String email}) {
    final previousName = customerName;
    customerName = name.trim().isEmpty ? customerName : name.trim();
    customerEmail = email.trim().isEmpty ? customerEmail : email.trim();
    for (final booking in _bookings) {
      if (booking.clientName == previousName) booking.clientName = customerName;
    }
    notifyListeners();
  }

  Booking? bookingById(String id) {
    for (final b in _bookings) {
      if (b.id == id) return b;
    }
    return null;
  }

  bool _isMine(Booking b) => b.clientName == customerName;

  // ---- payouts (how providers get their money) -------------------------------
  /// providerId -> bank account the provider's earnings are paid into.
  final Map<String, PayoutAccount> _payoutAccounts = {};
  final List<Payout> payouts = [];
  int _nextPayoutNumber = 1;

  PayoutAccount? payoutAccountFor(String providerId) => _payoutAccounts[providerId];
  PayoutAccount? get activePayoutAccount => _payoutAccounts[activeProvider.id];
  bool get hasPayoutAccount => activePayoutAccount != null;

  void savePayoutAccount(PayoutAccount account) {
    _payoutAccounts[activeProvider.id] = account;
    notifyListeners();
  }

  List<Payout> get providerPayouts => payouts
      .where((p) => p.providerId == activeProvider.id)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int payoutTotal(List<Payout> list, PayoutStatus status) =>
      list.where((p) => p.status == status).fold(0, (t, p) => t + p.amount);

  /// ConnectLocal's cut of each job, set by the admin (Earnings screen).
  double commissionRate = kDefaultCommissionRate;

  int commissionFor(int jobTotal) => (jobTotal * commissionRate).round();

  void setCommissionRate(double rate) {
    commissionRate = rate.clamp(0.0, 0.5);
    notifyListeners();
  }

  /// Total commission ConnectLocal has earned so far.
  int get commissionEarned => payouts.fold(0, (t, p) => t + p.commission);

  void _createPayout(Booking booking) {
    if (payouts.any((p) => p.bookingId == booking.id)) return;
    final now = DateTime.now();
    final id = 'PO-${_nextPayoutNumber++}';
    final commission = commissionFor(booking.price);
    // Online: ConnectLocal holds the whole price, so the provider gets it minus
    // the commission. Cash: the provider already took the balance in cash, so
    // ConnectLocal only owes them the deposit minus the commission (never below 0).
    final cash = booking.serviceMethod == PayMethod.cash;
    final net = cash
        ? (booking.bookingFee > commission ? booking.bookingFee - commission : 0)
        : booking.price - commission;
    // Paid out automatically to the provider's saved bank account.
    // TODO (backend): replace with a PayFast split payment / payout; the
    // reference below then comes from PayFast.
    payouts.add(Payout(
      id: id,
      providerId: booking.providerId,
      bookingId: booking.id,
      serviceName: booking.serviceName,
      clientName: booking.clientName,
      amount: net,
      jobTotal: booking.price,
      commission: commission,
      createdAt: now,
      status: PayoutStatus.paid,
      paidAt: now,
      reference: 'PF-$id',
    ));
    _notifyProvider(booking.providerId,
        'R$net for ${booking.serviceName} was paid to your bank account '
        '(job R${booking.price} minus ConnectLocal ${(commissionRate * 100).round()}%, ref PF-$id).');
  }

  // ---- payments (recorded so every transaction can be checked later) --------
  final List<PaymentRecord> payments = [];
  int _nextPaymentNumber = 1;

  /// Payments the customer made (deposits and service payments).
  List<PaymentRecord> get customerPayments {
    final mine = _bookings.where(_isMine).map((b) => b.id).toSet();
    return payments.where((p) => mine.contains(p.bookingId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  PaymentRecord _record(
    Booking booking,
    PaymentKind kind,
    PayMethod method,
    int amount, {
    String? gatewayReference,
    PaymentStatus status = PaymentStatus.paid,
    bool verified = false,
  }) {
    final record = PaymentRecord(
      id: 'PAY-${_nextPaymentNumber++}',
      bookingId: booking.id,
      kind: kind,
      method: method,
      amount: amount,
      createdAt: DateTime.now(),
      gatewayReference: gatewayReference,
      status: status,
      verified: verified,
    );
    payments.add(record);
    return record;
  }

  void _refund(Booking booking, PaymentKind kind) {
    for (final p in payments) {
      if (p.bookingId == booking.id && p.kind == kind &&
          (p.status == PaymentStatus.paid || p.status == PaymentStatus.held)) {
        p.status = PaymentStatus.refunded;
      }
    }
  }

  /// A fresh 4-digit PIN that no other open booking is using.
  String _generatePin() {
    final random = Random.secure();
    final inUse = _bookings
        .where((b) => b.status == BookingStatus.confirmed)
        .map((b) => b.completionPin)
        .toSet();
    String pin;
    do {
      pin = (1000 + random.nextInt(9000)).toString();
    } while (inUse.contains(pin));
    return pin;
  }

  /// Provider accepts or declines. (Completing a job goes through
  /// [startWithPin] / [completeJob], never through here.) The customer is told what happens
  /// next: pay the balance, fee refunded.
  void setStatus(Booking booking, BookingStatus status) {
    assert(status != BookingStatus.completed, 'Use completeJob to complete a job.');
    booking.status = status;
    if (status == BookingStatus.confirmed) {
      // Unique proof-of-service PIN, shown to the customer only.
      booking.completionPin ??= _generatePin();
    }
    if (status == BookingStatus.declined) {
      booking.feeRefunded = true;
      _refund(booking, PaymentKind.bookingFee);
    }
    {
      final who = providerById(booking.providerId).name;
      switch (status) {
        case BookingStatus.confirmed:
          _notifyCustomer(booking.clientName,
              '$who accepted your request. Your booking is secured. Give them your service PIN when they arrive; you pay the remaining R${booking.balance} after the service.');
        case BookingStatus.declined:
          _notifyCustomer(booking.clientName,
              '$who couldn’t take your booking. Your deposit of R${booking.bookingFee} will be refunded.');
        case BookingStatus.pending:
        case BookingStatus.completed:
        case BookingStatus.cancelled:
          break;
      }
    }
    notifyListeners();
  }

  /// The provider arrives and enters the PIN the customer reads out. This
  /// verifies the provider turned up for THIS booking and starts the job.
  PinResult startWithPin(Booking booking, String pin) {
    if (booking.status != BookingStatus.confirmed || booking.pinVerified) {
      return PinResult.notAllowed;
    }
    if (booking.pinAttempts >= kMaxPinAttempts) return PinResult.locked;
    if (pin.trim() != booking.completionPin) {
      booking.pinAttempts++;
      notifyListeners();
      return booking.pinAttempts >= kMaxPinAttempts ? PinResult.locked : PinResult.wrong;
    }
    booking.pinVerified = true;
    _notifyCustomer(booking.clientName,
        '${providerById(booking.providerId).name} arrived and was verified with your PIN. The job has started.');
    notifyListeners();
    return PinResult.ok;
  }

  /// The provider finishes the job (only after the PIN started it). The customer
  /// is then asked to pay the service cost.
  void completeJob(Booking booking) {
    if (booking.status != BookingStatus.confirmed || !booking.pinVerified) return;
    booking.status = BookingStatus.completed;
    _notifyCustomer(booking.clientName,
        'Your ${booking.serviceName} job is complete. Please pay the remaining R${booking.balance} '
        '(card, Instant EFT or cash) and leave a review.');
    notifyListeners();
  }

  /// The provider received the cash the customer chose to pay.
  void confirmCashReceived(Booking booking) {
    if (booking.status != BookingStatus.completed || booking.balancePaid) return;
    booking.balancePaid = true;
    for (final p in payments) {
      if (p.bookingId == booking.id &&
          p.kind == PaymentKind.service &&
          p.status == PaymentStatus.pending) {
        p.status = PaymentStatus.paid;
        p.verified = true; // confirmed by the provider
      }
    }
    _createPayout(booking);
    _notifyCustomer(booking.clientName,
        'Your cash payment of R${booking.balance} was confirmed. Thanks! Leave a review for ${providerById(booking.providerId).name}.');
    notifyListeners();
  }

  /// Customer cancels. Before the provider accepts, the deposit is refunded;
  /// after acceptance it is not. Returns a message to show the customer.
  String cancelBooking(Booking booking) {
    final wasPending = booking.status == BookingStatus.pending;
    booking.status = BookingStatus.cancelled;
    if (wasPending) {
      booking.feeRefunded = true;
      _refund(booking, PaymentKind.bookingFee);
    }
    if (booking.balancePaid) _refund(booking, PaymentKind.service);
    // A cash promise that was never handed over is simply dropped.
    payments.removeWhere((p) =>
        p.bookingId == booking.id &&
        p.kind == PaymentKind.service &&
        p.status == PaymentStatus.pending);
    _notifyProvider(
        booking.providerId, '${booking.clientName} cancelled ${booking.serviceName}.');
    notifyListeners();
    if (wasPending) return 'Booking cancelled. Your deposit of R${booking.bookingFee} will be refunded.';
    return booking.balancePaid
        ? 'Booking cancelled. Your R${booking.balance} payment will be refunded; the deposit is non-refundable.'
        : 'Booking cancelled. The deposit is non-refundable once a provider has accepted.';
  }

  /// The customer pays (card via PayFast) or promises to pay cash for the
  /// service AFTER the job is completed. [reference] is PayFast's payment id.
  void payBalance(Booking booking, {required PayMethod method, String? reference}) {
    booking.serviceMethod = method;
    if (method == PayMethod.cash) {
      // Cash is recorded as pending until the provider confirms receiving it.
      _record(booking, PaymentKind.service, PayMethod.cash, booking.balance,
          status: PaymentStatus.pending);
      _notifyProvider(booking.providerId,
          '${booking.clientName} will pay R${booking.balance} in cash for ${booking.serviceName}. Confirm when you have received it.');
    } else {
      // Paid online after the job: ConnectLocal now owes the provider this money.
      booking.balancePaid = true;
      _record(booking, PaymentKind.service, method, booking.balance,
          gatewayReference: reference, verified: true, status: PaymentStatus.paid);
      _createPayout(booking);
      _notifyProvider(booking.providerId,
          '${booking.clientName} paid R${booking.balance} online for ${booking.serviceName}.');
    }
    notifyListeners();
  }

  /// Saves the customer's review and updates the provider's rating.
  void addReview(Booking booking, {required int rating, String comment = ''}) {
    if (booking.rating != null) return;
    booking.rating = rating;
    booking.review = comment.trim();
    final p = providerById(booking.providerId);
    final total = p.rating * p.reviews + rating;
    p.reviews += 1;
    p.rating = double.parse((total / p.reviews).toStringAsFixed(1));
    notifyListeners();
  }

  /// Reviews left by customers for [providerId], newest first. Only completed
  /// (PIN-verified) jobs can be reviewed, so every review is from a real job.
  List<Booking> reviewsFor(String providerId) => _bookings
      .where((b) => b.providerId == providerId && b.rating != null)
      .toList()
    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  int bookingsThisMonth(ServiceModel service) {
    final now = DateTime.now();
    return _bookings.where((booking) =>
        booking.providerId == activeProvider.id &&
        booking.serviceId == service.id &&
        booking.dateTime.year == now.year &&
        booking.dateTime.month == now.month).length;
  }

  void toggleService(ServiceModel service) {
    service.active = !service.active;
    notifyListeners();
  }

  void updateService(
    ServiceModel service, {
    required String name,
    required String category,
    required int price,
    required String description,
    required List<PhotoRef> photos,
    List<ServicePackage> packages = const [],
    PricingType pricingType = PricingType.hourly,
  }) {
    service
      ..name = name
      ..category = category
      ..price = price
      ..description = description
      ..photos = List.of(photos)
      ..packages = List.of(packages)
      ..pricingType = pricingType;
    notifyListeners();
  }

  void addService({
    required String name,
    required String category,
    required int price,
    required String description,
    required List<PhotoRef> photos,
    List<ServicePackage> packages = const [],
    PricingType pricingType = PricingType.hourly,
  }) {
    activeProvider.services.add(ServiceModel(
      id: 'service-me-${_nextServiceNumber++}',
      name: name,
      category: category,
      price: price,
      description: description,
      photos: List.of(photos),
      packages: List.of(packages),
      pricingType: pricingType,
    ));
    notifyListeners();
  }

  /// Creates the request after the customer paid the deposit.
  /// [hourlyRate] x [hours] is the service cost (for a package: the package price x 1);
  /// the fee is 15% of that.
  String addCustomerBooking({
    required String providerId,
    required String serviceId,
    required String serviceName,
    required String date,
    required String time,
    required int hourlyRate,
    required int hours,
    required String address,
    double? latitude,
    double? longitude,
    String? packageName,
    String? paymentReference,
    PayMethod feeMethod = PayMethod.card,
    String notes = '',
  }) {
    final dateTime = _parseDateTime(date, time);
    final id = 'booking-demo-${_nextBookingNumber++}';
    final provider = providerById(providerId);
    if (address.trim().isNotEmpty) customerAddress = address.trim();
    _bookings.add(Booking(
      id: id,
      providerId: providerId,
      serviceId: serviceId,
      serviceName: serviceName,
      clientName: customerName,
      dateTime: dateTime,
      hours: hours,
      packageName: packageName,
      price: hourlyRate * hours,
      distanceKm: provider.distanceKm,
      phone: verifiedPhone ?? customerPhone,
      address: customerAddress,
      notes: notes,
      // The provider confirms or declines new requests.
      status: BookingStatus.pending,
    )
      ..latitude = latitude
      ..longitude = longitude);
    // The deposit is always paid by card (PayFast) before the request is sent.
    final created = _bookings.last;
    _record(created, PaymentKind.bookingFee, feeMethod, created.bookingFee,
        gatewayReference: paymentReference, verified: true);
    _notifyProvider(providerId, 'New booking request from $customerName for $serviceName${packageName == null ? '' : ' ($packageName)'}.');
    notifyListeners();
    return id;
  }

  DateTime _parseDateTime(String date, String time) {
    const monthNumbers = <String, int>{
      'January': 1, 'February': 2, 'March': 3, 'April': 4,
      'May': 5, 'June': 6, 'July': 7, 'August': 8,
      'September': 9, 'October': 10, 'November': 11, 'December': 12,
    };
    final parts = date.split(' ');
    final day = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? DateTime.now().day;
    final month = monthNumbers[parts.length > 1 ? parts[1] : ''] ?? DateTime.now().month;
    final year = int.tryParse(parts.length > 2 ? parts[2] : '') ?? DateTime.now().year;
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false).firstMatch(time);
    var hour = int.tryParse(match?.group(1) ?? '') ?? 9;
    final minute = int.tryParse(match?.group(2) ?? '') ?? 0;
    final period = (match?.group(3) ?? '').toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return DateTime(year, month, day, hour, minute);
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget.');
    return scope!.notifier!;
  }

  static AppState read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    final scope = element?.widget as AppScope?;
    assert(scope != null, 'AppScope is missing above this widget.');
    return scope!.notifier!;
  }
}
