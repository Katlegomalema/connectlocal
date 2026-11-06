import '../../shared/sa_time.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api_client.dart';
import '../../../core/connect_local_repository.dart';
import '../../shared/photo.dart';
import '../models/models.dart';
import '../utils/format.dart';

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

/// After this many wrong PINs the job is locked (protects against guessing). The server enforces it.
const int kMaxPinAttempts = 5;

/// What the app shows, loaded from the ConnectLocal API. Nothing is kept on the device except the sign-in
/// tokens (core/api_client.dart): every change goes to the server first, and the screens show what the
/// server answered.
class AppState extends ChangeNotifier {
  AppState();

  /// The ConnectLocal service categories, in the order the app shows them ("Other" always last).
  /// The database has the same list (supabase/migrations/20261105200000_connectlocal_categories.sql).
  static const List<String> kCategories = <String>[
    'Beauty & Health',
    'Healthcare',
    'Plumbing',
    'Cleaning Services',
    'Education & Tutoring',
    'Automotive Services',
    'Electrical Services',
    'Events & Photography',
    'Home Maintenance',
    'Other',
  ];

  /// Category names shown in the app. [loadFromServer] replaces them with the server's active
  /// categories, sorted in the [kCategories] order (unknown names just before "Other").
  static List<String> categories = List.of(kCategories);

  /// Sorts category names in the [kCategories] order.
  static List<String> sortCategories(Iterable<String> names) {
    String key(String name) => name.trim().toLowerCase();
    final byKey = {for (final n in names) key(n): n};
    final known = [
      for (final c in kCategories)
        if (byKey.containsKey(key(c))) byKey[key(c)]!,
    ];
    final other = known.isNotEmpty && key(known.last) == 'other' ? [known.removeLast()] : <String>[];
    final knownKeys = {for (final c in kCategories) key(c)};
    final unknown = [for (final n in byKey.values) if (!knownKeys.contains(key(n))) n];
    return [...known, ...unknown, ...other];
  }

  /// The ConnectLocal API (set in main.dart / main_admin.dart).
  ConnectLocalRepository? repository;

  /// Last problem talking to the server (shown by screens that want to), or null.
  String? serverError;

  ConnectLocalRepository get _repo {
    final repo = repository;
    if (repo == null) throw const ApiException('This app is not connected to the ConnectLocal server.');
    return repo;
  }

  /// Runs a server call and turns failures into a message for the screen (null = it worked).
  Future<String?> _attempt(Future<void> Function(ConnectLocalRepository repo) call) async {
    try {
      await call(_repo);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  // ---- the signed-in person ----------------------------------------------------------------------------
  String userId = '';
  String customerName = '';
  String customerEmail = '';
  String customerPhone = '';

  /// The profile picture chosen in this session (not stored on the server yet).
  PhotoRef? customerPhoto;

  /// The customer's verified mobile number (e.g. "+27 82 123 4567"), or null.
  String? verifiedPhone;

  /// True once the customer's email address was confirmed.
  bool emailVerified = false;

  /// A genuine client: confirmed email AND confirmed phone number.
  bool get isClientVerified => emailVerified && verifiedPhone != null;

  /// 'customer' or 'provider' (the account type chosen at sign-up, from the server).
  String accountRole = 'customer';

  /// True for an approved provider (Provider mode is only offered to them).
  bool isProvider = false;

  /// True when the person chose "I offer a service" on the Register screen (only until sign-in).
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

  /// Called after a successful sign-in with what the server returned.
  void signIn({
    required String name,
    required String email,
    required bool isProvider,
    String userId = '',
    String role = 'customer',
    bool emailVerified = true,
    String? verifiedPhone,
  }) {
    this.userId = userId;
    accountRole = role;
    customerName = name.trim();
    customerEmail = email.trim();
    this.emailVerified = emailVerified;
    this.verifiedPhone = verifiedPhone;
    customerPhone = verifiedPhone ?? '';
    this.isProvider = isProvider;
    notifyListeners();
  }

  /// Forgets everything about the previous person (after logging out).
  void signOut() {
    _liveTimer?.cancel();
    _liveTimer = null;
    userId = '';
    accountRole = 'customer';
    customerName = '';
    customerEmail = '';
    customerPhone = '';
    customerAddress = '';
    customerPhoto = null;
    verifiedPhone = null;
    emailVerified = false;
    isProvider = false;
    businessDescription = '';
    businessLocation = '';
    serverApplication = null;
    _myBusinessId = null;
    _bookings.clear();
    _feePaid.clear();
    _chats.clear();
    _conversations.clear();
    _notifications.clear();
    _reviews.clear();
    _busy.clear();
    payments.clear();
    payouts.clear();
    _payoutAccount = null;
    providerApplications.clear();
    adminUsers.clear();
    adminStats = const {};
    providers.removeWhere((p) => p.id != _noProvider.id && !_listed.contains(p.id));
    notifyListeners();
  }

  Future<String?> updateCustomerProfile({required String name, required String email}) async {
    if (email.trim().toLowerCase() != customerEmail.trim().toLowerCase()) {
      return 'Your email address cannot be changed here.';
    }
    final clean = name.trim();
    if (clean.length < 2 || clean == customerName) return null;
    final error = await _attempt((r) => r.updateMyName(userId, clean));
    if (error == null) {
      customerName = clean;
      notifyListeners();
    }
    return error;
  }

  void setCustomerPhoto(PhotoRef? photo) {
    customerPhoto = photo;
    notifyListeners();
  }

  void setVerifiedPhone(String? number) {
    verifiedPhone = number;
    notifyListeners();
  }

  // ---- location (real GPS distance to providers) ------------------------------------------------------
  /// The "Location services" switch in Settings.
  bool locationEnabled = true;
  LocationStatus locationStatus = LocationStatus.unknown;
  double? userLatitude;
  double? userLongitude;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _liveTimer?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  Future<void> setLocationEnabled(bool value) {
    locationEnabled = value;
    return refreshLocation();
  }

  /// Asks for permission (if needed), reads the GPS position and recalculates every provider's distance.
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
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
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

  // ---- loading -----------------------------------------------------------------------------------------
  Timer? _liveTimer;

  /// Categories, verified providers (search), and for a signed-in person their bookings, notifications,
  /// chats and payments; for a provider also their own business and payouts.
  Future<void> loadFromServer() async {
    final repo = repository;
    if (repo == null) return;
    try {
      final serverCategories = await repo.categories();
      if (serverCategories.isNotEmpty) categories = sortCategories([for (final c in serverCategories) c.name]);
      final listed = await repo.searchProviders();
      _listed
        ..clear()
        ..addAll(listed.map((p) => p.id));
      providers
        ..removeWhere((p) => p.id != _myBusinessId)
        ..addAll(listed.where((p) => p.id != _myBusinessId));
      serverError = null;
    } on ApiException catch (e) {
      serverError = e.message;
    }
    if (customerEmail.isNotEmpty) {
      await _loadMyBusiness();
      await Future.wait([refreshBookings(), refreshNotifications(), refreshConversations(), refreshMyPayments()]);
      _startLiveUpdates();
    }
    _updateDistances();
    notifyListeners();
  }

  /// While signed in: new notifications, messages and booking changes show up without a manual refresh.
  void _startLiveUpdates() {
    _liveTimer ??= Timer.periodic(const Duration(seconds: 30), (_) async {
      if (customerEmail.isEmpty) return;
      await Future.wait([refreshNotifications(), refreshConversations(), refreshBookings()]);
    });
  }

  // ---- providers and search ------------------------------------------------------------------------------
  /// Shown only while the signed-in person owns no business yet (never listed).
  final ProviderModel _noProvider = ProviderModel(
    id: 'provider-none',
    name: 'Your business',
    rating: 0,
    reviews: 0,
    distanceKm: 0,
    services: [],
  );

  /// Verified businesses from the search API, plus the signed-in provider's own business.
  final List<ProviderModel> providers = [];
  final Set<String> _listed = {};
  String? _myBusinessId;

  /// The signed-in provider's application on the server (null = none yet / not a provider).
  MyApplication? serverApplication;

  /// For a signed-in provider: their application status and (once approved) their own business.
  Future<void> _loadMyBusiness() async {
    final repo = repository;
    // Only provider accounts have a business: asking for a customer was a 403 on every sign-in.
    if (repo == null || customerEmail.isEmpty || accountRole != 'provider') return;
    try {
      serverApplication = await repo.myApplication();
      final server = serverApplication;
      if (server == null) return;
      _syncMyApplicationRecord(server);
      final business = await repo.myBusiness();
      if (business == null) return;
      providers.removeWhere((p) => p.id == business.id);
      providers.add(business);
      _myBusinessId = business.id;
      businessDescription = business.description;
      businessLocation = business.address;
      isProvider = server.isApproved;
      _applySchedule(business, await repo.mySchedule());
      if (isProvider) {
        await Future.wait([refreshPayouts(), loadReviews(business.id)]);
      }
    } on ApiException catch (e) {
      // 403 = not a provider account; nothing to load.
      if (e.statusCode != 403) serverError = e.message;
    }
  }

  List<ProviderModel> search({String query = '', String category = 'ALL', bool nearestFirst = false}) {
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
      return provider.id != _myBusinessId && categoryMatch && textMatch && active.isNotEmpty;
    }).toList();
    if (nearestFirst && locationStatus == LocationStatus.ready) {
      matches.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } else {
      matches.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return matches;
  }

  ProviderModel providerById(String id) =>
      providers.firstWhere((provider) => provider.id == id, orElse: () => _noProvider);

  ProviderModel? providerOwnedBy(String email) =>
      email.trim().toLowerCase() == customerEmail.trim().toLowerCase() && _myBusinessId != null
          ? providerById(_myBusinessId!)
          : null;

  ProviderModel get activeProvider => _myBusinessId == null ? _noProvider : providerById(_myBusinessId!);

  /// Business name, description and address (with the map point when the address changed).
  Future<String?> updateBusinessProfile({
    required String name,
    required String description,
    required String location,
    double? latitude,
    double? longitude,
  }) async {
    final error = await _attempt((r) => r.updateMyBusiness(
          name: name,
          description: description,
          address: location,
          latitude: latitude,
          longitude: longitude,
        ));
    if (error != null) return error;
    final me = activeProvider;
    if (latitude != null && longitude != null) {
      me
        ..latitude = latitude
        ..longitude = longitude;
      _updateDistances();
    }
    if (name.trim().isNotEmpty) me.name = name.trim();
    businessDescription = description.trim();
    businessLocation = location.trim();
    notifyListeners();
    return null;
  }

  /// Uploads a business photo (customers see the newest one first).
  Future<String?> setBusinessPhoto(PhotoRef? photo) async {
    if (photo == null) return null;
    String? url;
    final error = await _attempt((r) async => url = await r.addBusinessPhoto(photo));
    if (error != null) return error;
    activeProvider.avatar = url == null ? photo : PhotoRef(url: url, name: photo.name);
    notifyListeners();
    return null;
  }

  // ---- booking options, working hours and time slots ----------------------------------------------------
  /// Times taken at each provider (from the server; start + minutes, no customer details).
  final Map<String, List<({DateTime start, int minutes})>> _busy = {};

  void _applySchedule(ProviderModel provider, ProviderSchedule schedule) {
    provider
      ..offersVisit = schedule.offersVisit
      ..offersHouseCall = schedule.offersHouseCall
      ..workingHours = schedule.hours;
  }

  /// Loads a provider's booking options, hours and taken times (call when their profile or booking
  /// screen opens). Returns an error message, or null.
  Future<String?> loadSchedule(String providerId) => _attempt((r) async {
        final schedule = await r.providerSchedule(providerId);
        _applySchedule(providerById(providerId), schedule);
        _busy[providerId] = schedule.busy;
        notifyListeners();
      });

  /// Tests: the taken times as GET /providers/:id/schedule would send them.
  @visibleForTesting
  void setBusyTimes(String providerId, List<({DateTime start, int minutes})> busy) {
    _busy[providerId] = busy;
    notifyListeners();
  }

  /// True when [minutes] from [start] are free with this provider: inside working hours, and at least
  /// [kBookingGapMinutes] away from every other booking that still holds its slot (before and after).
  /// The server checks the same rule again when the booking is made.
  bool slotIsFree(String providerId, DateTime start, int minutes) {
    final provider = providerById(providerId);
    if (!provider.workingHours.fitsInDay(start, minutes)) return false;
    bool clashes(DateTime otherStart, int otherMinutes) =>
        timesOverlap(otherStart, otherMinutes + kBookingGapMinutes, start, minutes + kBookingGapMinutes);
    final taken = _busy[providerId] ?? const [];
    // Also this person's own bookings (e.g. one made a moment ago, before the list was reloaded).
    return !taken.any((b) => clashes(b.start, b.minutes)) &&
        !_bookings.any((b) => b.providerId == providerId && b.holdsSlot && clashes(b.dateTime, b.blockedMinutes));
  }

  /// The slots of [day] that have not started yet, each with whether a booking of [minutes] can start
  /// there (false = booked by someone else, or not enough time before closing).
  List<({DateTime start, bool free})> slotsFor(String providerId, DateTime day, int minutes) {
    final now = nowSast();
    return [
      for (final start in providerById(providerId).workingHours.slotStarts(day))
        if (start.isAfter(now)) (start: start, free: slotIsFree(providerId, start, minutes)),
    ];
  }

  /// The provider's own working hours and slot length (saved on the server). Returns an error, or null.
  Future<String?> setWorkingHours(WorkingHours hours) => _attempt((r) async {
        _applySchedule(activeProvider, await r.saveMySchedule(hours: hours));
        notifyListeners();
      });

  /// Which booking options the provider offers. At least one must stay on. Returns an error, or null.
  Future<String?> setBookingOptions({required bool visit, required bool houseCall}) async {
    if (!visit && !houseCall) return 'Choose at least one way customers can book you.';
    if (visit && !activeProvider.hasBusinessLocation) {
      return 'Add your business address first, so customers can find you.';
    }
    return _attempt((r) async {
      _applySchedule(activeProvider, await r.saveMySchedule(offersVisit: visit, offersHouseCall: houseCall));
      notifyListeners();
    });
  }

  // ---- services (provider) -------------------------------------------------------------------------------
  int bookingsThisMonth(ServiceModel service) {
    final now = DateTime.now();
    return _bookings
        .where((booking) =>
            booking.providerId == activeProvider.id &&
            booking.serviceId == service.id &&
            booking.dateTime.year == now.year &&
            booking.dateTime.month == now.month)
        .length;
  }

  /// Shows/hides a service. Returns an error message, or null.
  Future<String?> toggleService(ServiceModel service) async {
    final error = await _attempt((r) => r.setServiceActive(service.id, !service.active));
    if (error != null) return error;
    service.active = !service.active;
    notifyListeners();
    return null;
  }

  /// Creates ([service] null) or updates a service on the server, then reloads the business.
  Future<String?> saveService(
    ServiceModel? service, {
    required String name,
    required String category,
    required double price,
    required String description,
    required List<PhotoRef> photos,
    List<ServicePackage> packages = const [],
    PricingType pricingType = PricingType.hourly,
  }) async {
    final error = await _attempt((r) => r.saveService(
          serviceId: service?.id,
          name: name,
          category: category,
          price: price,
          description: description,
          pricingType: pricingType,
          packages: packages,
          existingPackageIds: service?.serverPackageIds ?? const {},
          photos: photos,
        ));
    if (error != null) return error;
    await _loadMyBusiness();
    notifyListeners();
    return null;
  }

  // ---- provider applications ---------------------------------------------------------------------------
  /// The signed-in person's own application (mine), or all applications on the admin website.
  final List<ProviderApplicationRecord> providerApplications = [];

  List<ProviderApplicationRecord> applicationsWithStatus(ApplicationStatus status) =>
      providerApplications.where((a) => a.status == status).toList();

  /// The latest application sent by the person using the app (or null).
  ProviderApplicationRecord? get myApplication {
    for (final a in providerApplications) {
      if (a.mine) return a;
    }
    return null;
  }

  /// Mirrors the server's application status into the "mine" record the screens read ([myApplication]).
  void _syncMyApplicationRecord(MyApplication server) {
    final status = switch (server.status) {
      'approved' => ApplicationStatus.approved,
      'rejected' => ApplicationStatus.rejected,
      'submitted' => ApplicationStatus.pending,
      _ => null, // draft: not sent yet
    };
    if (status == null) return;
    final existing = myApplication;
    if (existing != null) {
      existing
        ..status = status
        ..rejectionReason = server.rejectionReason;
      return;
    }
    providerApplications.insert(
      0,
      ProviderApplicationRecord(
        id: server.providerId,
        businessName: server.businessName,
        email: customerEmail,
        services: '',
        applicantName: customerName,
        appliedAt: DateTime.now(),
        mine: true,
        status: status,
      )..rejectionReason = server.rejectionReason,
    );
  }

  /// Sends the "Become a provider" application. Returns an error message, or null when it was sent.
  Future<String?> sendProviderApplication({
    required String businessName,
    required String category,
    required String description,
    required String location,
    required String registrationNumber,
    required PhotoRef registrationDoc,
    required PhotoRef idDoc,
    required double latitude,
    required double longitude,
    String idNumber = '', // checked by the admin on the ID document; never sent or stored (privacy)
    List<PhotoRef> photos = const [],
    void Function(String step, int done, int total)? onProgress,
  }) async {
    final error = await _attempt((r) async {
      serverApplication = await r.submitApplication(
        businessName: businessName,
        category: category,
        description: description,
        address: location,
        registrationNumber: registrationNumber,
        latitude: latitude,
        longitude: longitude,
        registrationDoc: registrationDoc,
        idDoc: idDoc,
        photos: photos,
        onProgress: onProgress,
      );
    });
    if (error != null) return error;
    providerApplications.removeWhere((a) => a.mine);
    _syncMyApplicationRecord(serverApplication!);
    businessDescription = description;
    businessLocation = location;
    notifyListeners();
    return null;
  }

  // ---- bookings ----------------------------------------------------------------------------------------
  final List<Booking> _bookings = [];

  /// Bookings whose 15% fee reached ConnectLocal (PayFast ITN). Until then the provider cannot accept.
  final Set<String> _feePaid = {};
  bool feePaid(Booking b) => _feePaid.contains(b.id);

  List<Booking> get customerBookings =>
      _bookings.where((booking) => booking.customerId == userId).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  /// The provider's bookings. A request whose 15% fee is not paid yet is left out: it cannot be accepted
  /// (and is dropped if the customer never pays).
  List<Booking> get providerBookings => _bookings
      .where((booking) =>
          booking.providerId == activeProvider.id &&
          (booking.status != BookingStatus.pending || _feePaid.contains(booking.id)))
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  /// Every booking (admin website), newest first.
  List<Booking> get allBookings =>
      List.unmodifiable(_bookings.toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime)));

  List<Booking> get todayBookings {
    final now = DateUtils.dateOnly(nowSast());
    return providerBookings.where((booking) => DateUtils.dateOnly(booking.dateTime) == now).toList();
  }

  int get pendingCount => providerBookings.where((booking) => booking.status == BookingStatus.pending).length;

  double get totalEarned => providerBookings
      .where((booking) => booking.status == BookingStatus.completed)
      .fold<double>(0, (sum, booking) => sum + booking.price);

  Booking? bookingById(String id) {
    for (final b in _bookings) {
      if (b.id == id) return b;
    }
    return null;
  }

  static BookingStatus _statusFromServer(String? status) => switch (status) {
        'accepted' || 'in_progress' => BookingStatus.confirmed,
        'completed' => BookingStatus.completed,
        'rejected' => BookingStatus.declined,
        'cancelled' => BookingStatus.cancelled,
        _ => BookingStatus.pending,
      };

  static double _num(Object? v) => switch (v) { num n => n.toDouble(), String s => double.tryParse(s) ?? 0, _ => 0 };

  /// Creates or updates the app's [Booking] from a server booking (in place, so screens holding the object
  /// see the change).
  Booking _fromServer(Map<String, dynamic> json) {
    final id = json['id'] as String;
    if (json['booking_fee_status'] == 'paid') {
      _feePaid.add(id);
    } else if (json.containsKey('booking_fee_status')) {
      _feePaid.remove(id);
    }
    final customer = (json['customer'] as Map?) ?? const {};
    final service = (json['service'] as Map?) ?? const {};
    final provider = (json['provider'] as Map?) ?? const {};
    final reviewJson = json['review'];
    final review = reviewJson is List ? (reviewJson.isEmpty ? null : reviewJson.first) : reviewJson;
    final location = json['service_location'];

    Booking? existing = bookingById(id);
    final booking = existing ??
        Booking(
          id: id,
          providerId: json['provider_id'] as String,
          serviceId: json['service_id'] as String,
          serviceName: (service['service_name'] as String?) ?? 'Service',
          clientName: (customer['full_name'] as String?) ?? '',
          customerId: json['customer_id'] as String?,
          dateTime: sastWall(DateTime.tryParse((json['scheduled_start'] as String?) ?? '') ?? DateTime.now()),
          price: _num(json['total_amount']),
          hours: (json['quantity'] as num?)?.toInt() ?? 1,
          packageName: json['package_name_at_booking'] as String?,
          bookingFee: _num(json['booking_fee_amount']),
          address: (json['service_address'] as String?) ?? '',
          notes: (json['notes'] as String?) ?? '',
          atBusiness: json['at_business'] == true,
          blockedMinutes: _blockedMinutesOf(json),
        );
    if (existing == null) {
      booking
        ..latitude = location is Map ? _num(location['latitude']) : null
        ..longitude = location is Map ? _num(location['longitude']) : null;
      _bookings.add(booking);
    }
    booking
      ..status = _statusFromServer(json['status'] as String?)
      ..clientName = (customer['full_name'] as String?) ?? booking.clientName
      ..phone = (customer['phone_number'] as String?) ?? booking.phone
      ..businessName = (provider['business_name'] as String?) ?? booking.businessName
      ..balanceAmount = json['balance_amount'] == null ? booking.balanceAmount : _num(json['balance_amount'])
      ..balancePaid = json['balance_status'] == 'paid'
      ..feeRefunded = json['booking_fee_status'] == 'refunded'
      ..serviceMethod = switch (json['balance_payment_method']) {
        'card' => PayMethod.card,
        'cash' => PayMethod.cash,
        _ => null,
      }
      ..pinAttempts = (json['arrival_pin_attempts'] as num?)?.toInt() ?? booking.pinAttempts
      ..pinVerified = json['arrival_pin_verified_at'] != null;
    if (review is Map) {
      booking
        ..rating = (review['rating'] as num?)?.toInt()
        ..review = review['review_text'] as String?;
    }
    return booking;
  }

  /// How long a server booking holds the provider's time (end - start; falls back to its duration).
  static int _blockedMinutesOf(Map<String, dynamic> json) {
    final start = DateTime.tryParse((json['scheduled_start'] as String?) ?? '');
    final end = DateTime.tryParse((json['scheduled_end'] as String?) ?? '');
    if (start != null && end != null && end.isAfter(start)) return end.difference(start).inMinutes;
    return (json['duration_minutes_at_booking'] as num?)?.toInt() ?? 60;
  }

  /// Reloads the signed-in person's bookings; customers also get the PIN for accepted bookings.
  Future<String?> refreshBookings() async {
    final repo = repository;
    if (repo == null || customerEmail.isEmpty) return null;
    try {
      final rows = await repo.myBookings();
      for (final row in rows) {
        final booking = _fromServer(row);
        final isMine = booking.customerId == userId;
        if (isMine && row['status'] == 'accepted' && booking.completionPin == null) {
          booking.completionPin = await repo.arrivalPin(booking.id);
        }
      }
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Customer: create the booking request on the server (the fee is paid right after). Returns the booking.
  Future<Booking> createServerBooking({
    required String providerId,
    required String serviceId,
    required String date,
    required String time,
    required int hours,
    required String address,
    bool atBusiness = false,
    String? packageName,
    double? latitude,
    double? longitude,
    String notes = '',
  }) async {
    final service = providerById(providerId).services.where((s) => s.id == serviceId).firstOrNull;
    final packageId = packageName == null ? null : service?.serverPackageIds[packageName];
    final json = await _repo.createBooking(
      providerId: providerId,
      serviceId: serviceId,
      scheduledStart: _parseDateTime(date, time),
      address: address,
      atBusiness: atBusiness,
      hours: service?.pricingType == PricingType.hourly ? hours : null,
      packageId: packageId,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
    );
    // House call: remember the customer's address for next time. A business visit has no customer address.
    if (!atBusiness && address.trim().isNotEmpty) customerAddress = address.trim();
    final booking = _fromServer(json);
    unawaited(loadSchedule(providerId)); // the slot is now taken
    notifyListeners();
    return booking;
  }

  /// Reloads one booking (after a payment).
  Future<Booking?> reloadBooking(String id) async {
    final repo = repository;
    if (repo == null) return null;
    final booking = _fromServer(await repo.booking(id));
    notifyListeners();
    return booking;
  }

  Future<String?> _bookingCall(Future<Map<String, dynamic>> Function(ConnectLocalRepository r) call) =>
      _attempt((r) async {
        _fromServer(await call(r));
        notifyListeners();
      });

  /// Provider accepts (confirmed) or declines. Returns an error message, or null.
  Future<String?> setStatus(Booking booking, BookingStatus status) => switch (status) {
        BookingStatus.confirmed => _bookingCall((r) => r.accept(booking.id)),
        BookingStatus.declined => _bookingCall((r) => r.decline(booking.id)),
        _ => Future.value('That change is not allowed here.'),
      };

  /// Provider enters the PIN on arrival. The server checks it (5 tries).
  Future<({PinResult result, String? message})> startWithPin(Booking booking, String pin) async {
    try {
      _fromServer(await _repo.startWithPin(booking.id, pin));
      notifyListeners();
      return (result: PinResult.ok, message: null);
    } on ApiException catch (e) {
      // Reload to show the real number of tries left.
      try {
        await reloadBooking(booking.id);
      } on ApiException {
        // keep the message below
      }
      final locked = e.message.contains('Too many') || e.message.contains('No tries left');
      final wrong = e.message.startsWith('Wrong PIN');
      return (
        result: locked ? PinResult.locked : (wrong ? PinResult.wrong : PinResult.notAllowed),
        message: e.message,
      );
    }
  }

  Future<String?> completeJob(Booking booking) => _bookingCall((r) => r.complete(booking.id));

  /// Provider confirms cash received: the server records the payment, receipt and payout.
  Future<String?> confirmCashReceived(Booking booking) => _attempt((r) async {
        await r.confirmCash(booking.id);
        await reloadBooking(booking.id);
        await refreshPayouts();
      });

  /// Customer chose cash for the balance (saved on the server; the provider confirms it later).
  Future<String?> chooseCash(Booking booking) => _bookingCall((r) => r.chooseCash(booking.id));

  /// Customer cancels. Returns the message to show.
  Future<String> cancelBooking(Booking booking) async {
    try {
      final json = await _repo.cancel(booking.id);
      _fromServer(json);
      notifyListeners();
      return switch (json['feeRefund']) {
        'refunded' => 'Booking cancelled. Your deposit of ${money(booking.bookingFee)} was refunded.',
        'failed' => 'Booking cancelled. The deposit refund is being handled by ConnectLocal.',
        'kept' => 'Booking cancelled. The deposit is non-refundable after the provider accepted.',
        _ => 'Booking cancelled.',
      };
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> addReview(Booking booking, {required int rating, String comment = ''}) async {
    final error = await _attempt((r) => r.review(booking.id, rating, comment));
    if (error != null) return error;
    booking
      ..rating = rating
      ..review = comment.trim();
    notifyListeners();
    unawaited(loadReviews(booking.providerId));
    return null;
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

  // ---- chat (one per booking) ------------------------------------------------------------------------------
  final Map<String, List<ChatMessage>> _chats = {};
  final Map<String, ConversationSummary> _conversations = {};

  List<ChatMessage> chatFor(String bookingId) => List.unmodifiable(_chats[bookingId] ?? const <ChatMessage>[]);

  /// Latest message of a booking's chat (Messages list), or null when nobody wrote yet.
  ConversationSummary? conversationFor(String bookingId) => _conversations[bookingId];

  int get unreadMessages => _conversations.values.fold(0, (t, c) => t + c.unread);

  /// Loads a booking's chat (and marks what you received as read on the server).
  Future<String?> loadChat(String bookingId) => _attempt((r) async {
        final messages = await r.bookingMessages(bookingId);
        final before = _chats[bookingId];
        final changed = before == null ||
            before.length != messages.length ||
            (messages.isNotEmpty && before.last.id != messages.last.id);
        _chats[bookingId] = messages;
        final summary = _conversations[bookingId];
        if (summary != null && summary.unread > 0) {
          _conversations[bookingId] = ConversationSummary(
            bookingId: bookingId,
            lastMessage: summary.lastMessage,
            lastAt: summary.lastAt,
            lastMine: summary.lastMine,
            unread: 0,
          );
          notifyListeners();
        } else if (changed) {
          notifyListeners();
        }
      });

  /// Sends a chat message. Returns an error message, or null.
  Future<String?> sendMessage(String bookingId, String text) => _attempt((r) async {
        final sent = await r.sendMessage(bookingId, text);
        (_chats[bookingId] ??= []).add(sent);
        _conversations[bookingId] = ConversationSummary(
          bookingId: bookingId,
          lastMessage: sent.text,
          lastAt: sent.sentAt,
          lastMine: true,
          unread: 0,
        );
        notifyListeners();
      });

  Future<String?> refreshConversations() async {
    if (repository == null || customerEmail.isEmpty) return null;
    return _attempt((r) async {
      final list = await r.conversations();
      _conversations
        ..clear()
        ..addAll({for (final c in list) c.bookingId: c});
      notifyListeners();
    });
  }

  // ---- notifications ---------------------------------------------------------------------------------------
  final List<AppNotification> _notifications = [];

  /// The signed-in person's notifications, newest first (the same list in customer and provider mode).
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  List<AppNotification> get customerNotifications => notifications;
  int get unreadNotifications => _notifications.where((n) => !n.isRead).length;
  int get unreadCustomerNotifications => unreadNotifications;

  Future<String?> refreshNotifications() async {
    if (repository == null || customerEmail.isEmpty) return null;
    return _attempt((r) async {
      final list = await r.notifications();
      _notifications
        ..clear()
        ..addAll(list);
      notifyListeners();
    });
  }

  Future<String?> markNotificationsRead() async {
    if (unreadNotifications == 0) return null;
    final error = await _attempt((r) => r.markAllNotificationsRead());
    if (error == null) {
      for (final n in _notifications) {
        n.isRead = true;
      }
      notifyListeners();
    }
    return error;
  }

  Future<String?> markCustomerNotificationsRead() => markNotificationsRead();

  // ---- reviews -------------------------------------------------------------------------------------------
  final Map<String, List<ReviewItem>> _reviews = {};

  /// Reviews of [providerId] as last loaded (newest first). Call [loadReviews] to refresh.
  List<ReviewItem> reviewsFor(String providerId) => List.unmodifiable(_reviews[providerId] ?? const <ReviewItem>[]);

  Future<String?> loadReviews(String providerId) => _attempt((r) async {
        _reviews[providerId] = await r.providerReviews(providerId);
        notifyListeners();
      });

  // ---- payments ------------------------------------------------------------------------------------------
  /// The signed-in person's payments, or every payment on the admin website.
  final List<PaymentRecord> payments = [];

  /// Payments the customer made (deposits and balances), newest first.
  List<PaymentRecord> get customerPayments => payments.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<String?> refreshMyPayments() async {
    if (repository == null || customerEmail.isEmpty) return null;
    return _attempt((r) async {
      final list = await r.myPayments();
      payments
        ..clear()
        ..addAll(list);
      notifyListeners();
    });
  }

  // ---- payouts (how providers get their money) -------------------------------------------------------------
  PayoutAccount? _payoutAccount;
  final List<Payout> payouts = [];

  PayoutAccount? get activePayoutAccount => _payoutAccount;
  bool get hasPayoutAccount => _payoutAccount != null;

  /// The app only ever keeps the last 4 digits of the saved account number.
  static PayoutAccount _accountFromServer(Map<String, dynamic> d) => PayoutAccount(
        bank: (d['bankName'] as String?) ?? '',
        accountType: (d['accountType'] as String?) ?? '',
        holderName: (d['accountHolderName'] as String?) ?? '',
        accountNumber: '•••••${d['accountLast4'] ?? ''}',
        branchCode: (d['branchCode'] as String?) ?? '',
      );

  /// Saves bank details on the server (encrypted there). Returns an error message, or null.
  Future<String?> savePayoutDetails(PayoutAccount account) => _attempt((r) async {
        final saved = await r.savePayoutDetails(
          bankName: account.bank,
          accountType: account.accountType,
          accountHolderName: account.holderName,
          accountNumber: account.accountNumber,
          branchCode: account.branchCode,
        );
        _payoutAccount = _accountFromServer(saved);
        notifyListeners();
      });

  /// Provider: reloads bank details (masked) and payouts from the server.
  Future<String?> refreshPayouts() async {
    if (repository == null) return null;
    final providerId = activeProvider.id;
    return _attempt((r) async {
      final details = await r.payoutDetails();
      _payoutAccount = details == null ? null : _accountFromServer(details);
      final rows = await r.myPayouts();
      payouts
        ..clear()
        ..addAll([for (final row in rows) ConnectLocalRepository.payoutFromJson(row, providerId: providerId)]);
      notifyListeners();
    });
  }

  List<Payout> get providerPayouts =>
      payouts.where((p) => p.providerId == activeProvider.id).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  double payoutTotal(List<Payout> list, PayoutStatus status) =>
      list.where((p) => p.status == status).fold<double>(0, (t, p) => t + p.amount);

  /// ConnectLocal's cut of each job (the server's value once the admin site loaded it).
  double commissionRate = kDefaultCommissionRate;

  /// ConnectLocal's commission on a job, exact to the cent (same as the backend).
  double commissionFor(num jobTotal) => roundMoney(jobTotal * commissionRate);

  /// Total commission ConnectLocal has earned so far (admin website).
  double get commissionEarned => payouts.fold<double>(0, (t, p) => t + p.commission);

  // ---- admin website ---------------------------------------------------------------------------------------
  final List<AdminUser> adminUsers = [];

  /// Platform numbers from GET /admin/analytics (totalUsers, totalProviders, totalBookings, ...).
  Map<String, dynamic> adminStats = const {};

  /// Loads everything the admin screens show. Returns an error message, or null.
  Future<String?> loadAdminData() => _attempt((r) async {
        final results = await Future.wait<Object>([
          r.adminAnalytics(),
          r.adminUsers(),
          r.adminBookings(),
          r.adminPayments(),
          r.adminPayouts(),
        ]);
        adminStats = results[0] as Map<String, dynamic>;
        commissionRate = _num(adminStats['commissionRate']) > 0 ? _num(adminStats['commissionRate']) : commissionRate;
        adminUsers
          ..clear()
          ..addAll(results[1] as List<AdminUser>);
        _bookings.clear();
        for (final row in results[2] as List<Map<String, dynamic>>) {
          _fromServer(row);
        }
        payments
          ..clear()
          ..addAll(results[3] as List<PaymentRecord>);
        payouts
          ..clear()
          ..addAll(results[4] as List<Payout>);
        notifyListeners();
      });

  /// Admin: suspend or re-activate an account. Returns an error message, or null.
  Future<String?> setUserActive(AdminUser user, bool active) async {
    final error = await _attempt((r) => r.setUserStatus(user.id, active ? 'active' : 'suspended'));
    if (error == null) {
      user.status = active ? 'active' : 'suspended';
      notifyListeners();
    }
    return error;
  }

  /// Admin website: load applications from the server (all three tabs).
  Future<String?> loadApplications() => _attempt((r) async {
        final results = await Future.wait([
          r.applications(status: 'pending'),
          r.applications(status: 'verified'),
          r.applications(status: 'rejected'),
        ]);
        providerApplications
          ..clear()
          ..addAll(results.expand((list) => list));
        notifyListeners();
      });

  /// Admin approves or rejects. Returns an error message, or null when done.
  Future<String?> decideApplication(ProviderApplicationRecord application, ApplicationStatus status,
      {String? reason}) async {
    final error = await _attempt((r) => status == ApplicationStatus.approved
        ? r.approve(application.id)
        : r.reject(application.id, reason ?? ''));
    if (error != null) return error;
    application
      ..status = status
      ..rejectionReason = reason;
    notifyListeners();
    return null;
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

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
