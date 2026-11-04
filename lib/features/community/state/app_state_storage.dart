part of 'app_state.dart';

/// Saves the whole app (applications, businesses, bookings, payments, chats,
/// notifications...) on this device so nothing disappears when the page is
/// refreshed or the app is restarted. This is the stand-in for the database.
///
/// BACKEND HAND-OVER: when Supabase arrives, delete this file and the
/// `loadSaved()` / `_scheduleSave()` calls. Each part below maps to one table.
const String kStorageKey = 'connect_local_state_v2';

/// Browsers allow roughly 5 MB per site, so photos are saved only until this
/// many characters have been used (documents first, then the rest).
const int _kPhotoBudgetChars = 3200000;

class _PhotoBudget {
  int used = 0;
  bool take(int chars) {
    if (used + chars > _kPhotoBudgetChars) return false;
    used += chars;
    return true;
  }
}

Map<String, dynamic>? _photoToJson(PhotoRef? p, _PhotoBudget budget) {
  if (p == null) return null;
  if (p.bytes != null) {
    final data = base64Encode(p.bytes!);
    if (!budget.take(data.length)) return null;
    return {'name': p.name, 'data': data};
  }
  return {'name': p.name, 'url': p.url};
}

PhotoRef? _photoFromJson(dynamic j) {
  if (j is! Map) return null;
  final name = (j['name'] as String?) ?? '';
  if (j['data'] is String) {
    return PhotoRef(bytes: base64Decode(j['data'] as String), name: name);
  }
  if (j['url'] is String) return PhotoRef(url: j['url'] as String, name: name);
  return null;
}

List<Map<String, dynamic>> _photosToJson(List<PhotoRef> list, _PhotoBudget b) => [
      for (final p in list)
        if (_photoToJson(p, b) case final j?) j,
    ];

List<PhotoRef> _photosFromJson(dynamic j) => [
      if (j is List)
        for (final p in j)
          if (_photoFromJson(p) case final photo?) photo,
    ];

T _enumByName<T extends Enum>(List<T> values, dynamic name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

extension AppStateStorage on AppState {
  Map<String, dynamic> toJson() {
    _syncAccount();
    final budget = _PhotoBudget();
    // Documents the admin must see come first so they are never the ones dropped.
    final applications = [
      for (final a in providerApplications)
        {
          'id': a.id,
          'businessName': a.businessName,
          'email': a.email,
          'services': a.services,
          'description': a.description,
          'location': a.location,
          'appliedAt': a.appliedAt.toIso8601String(),
          'registrationNumber': a.registrationNumber,
          'registrationDoc': _photoToJson(a.registrationDoc, budget),
          'idNumber': a.idNumber,
          'idDoc': _photoToJson(a.idDoc, budget),
          'applicantName': a.applicantName,
          'latitude': a.latitude,
          'longitude': a.longitude,
          'photos': _photosToJson(a.photos, budget),
          'mine': a.mine,
          'status': a.status.name,
          'rejectionReason': a.rejectionReason,
        },
    ];
    return {
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'verifiedPhone': verifiedPhone,
      'emailVerified': emailVerified,
      'isProvider': isProvider,
      'businessDescription': businessDescription,
      'businessLocation': businessLocation,
      'accounts': [
        for (final a in accounts)
          {
            'name': a.name,
            'email': a.email,
            'salt': a.salt,
            'passwordHash': a.passwordHash,
            'createdAt': a.createdAt.toIso8601String(),
            'emailVerified': a.emailVerified,
            'phone': a.phone,
            'verifiedPhone': a.verifiedPhone,
            'address': a.address,
            'disabled': a.disabled,
          },
      ],
      'nextBooking': _nextBookingNumber,
      'nextService': _nextServiceNumber,
      'nextPayment': _nextPaymentNumber,
      'nextPayout': _nextPayoutNumber,
      'commissionRate': commissionRate,
      'payoutAccounts': {
        for (final e in _payoutAccounts.entries)
          e.key: {
            'bank': e.value.bank,
            'accountType': e.value.accountType,
            'holderName': e.value.holderName,
            'accountNumber': e.value.accountNumber,
            'branchCode': e.value.branchCode,
          },
      },
      'payouts': [
        for (final p in payouts)
          {
            'id': p.id,
            'providerId': p.providerId,
            'bookingId': p.bookingId,
            'serviceName': p.serviceName,
            'clientName': p.clientName,
            'amount': p.amount,
            'jobTotal': p.jobTotal,
            'commission': p.commission,
            'createdAt': p.createdAt.toIso8601String(),
            'status': p.status.name,
            'paidAt': p.paidAt?.toIso8601String(),
            'reference': p.reference,
          },
      ],
      'customerPhoto': _photoToJson(customerPhoto, budget),
      'applications': applications,
      'owners': _providerOwner,
      'providers': [
        for (final p in providers)
          {
            'id': p.id,
            'name': p.name,
            'rating': p.rating,
            'reviews': p.reviews,
            'distanceKm': p.distanceKm,
            'latitude': p.latitude,
            'longitude': p.longitude,
            'verified': p.verified,
            'avatar': _photoToJson(p.avatar, budget),
            'services': [
              for (final s in p.services)
                {
                  'id': s.id,
                  'name': s.name,
                  'category': s.category,
                  'price': s.price,
                  'description': s.description,
                  'rating': s.rating,
                  'active': s.active,
                  'pricingType': s.pricingType.name,
                  'packages': [
                    for (final k in s.packages)
                      {'name': k.name, 'price': k.price, 'description': k.description},
                  ],
                  'photos': _photosToJson(s.photos, budget),
                },
            ],
          },
      ],
      'bookings': [
        for (final b in _bookings)
          {
            'id': b.id,
            'providerId': b.providerId,
            'serviceId': b.serviceId,
            'serviceName': b.serviceName,
            'clientName': b.clientName,
            'dateTime': b.dateTime.toIso8601String(),
            'hours': b.hours,
            'packageName': b.packageName,
            'price': b.price,
            'bookingFee': b.bookingFee,
            'balancePaid': b.balancePaid,
            'feeRefunded': b.feeRefunded,
            'rating': b.rating,
            'review': b.review,
            'serviceMethod': b.serviceMethod?.name,
            'completionPin': b.completionPin,
            'pinAttempts': b.pinAttempts,
            'pinVerified': b.pinVerified,
            'distanceKm': b.distanceKm,
            'phone': b.phone,
            'address': b.address,
            'lat': b.latitude,
            'lng': b.longitude,
            'notes': b.notes,
            'status': b.status.name,
          },
      ],
      'payments': [
        for (final p in payments)
          {
            'id': p.id,
            'bookingId': p.bookingId,
            'kind': p.kind.name,
            'method': p.method.name,
            'amount': p.amount,
            'createdAt': p.createdAt.toIso8601String(),
            'gatewayReference': p.gatewayReference,
            'status': p.status.name,
            'verified': p.verified,
          },
      ],
      'chats': {
        for (final e in _chats.entries)
          e.key: [
            for (final m in e.value)
              {
                'text': m.text,
                'sentAt': m.sentAt.toIso8601String(),
                'fromProvider': m.fromProvider,
              },
          ],
      },
      'providerNotes': _providerNotes,
      'providerUnread': _providerUnread,
      'customerNotes': _customerNotes,
      'customerUnread': _customerUnread,
    };
  }

  /// Puts saved data back. Anything missing or damaged is skipped, so a bad
  /// save can never stop the app from starting.
  void restoreFrom(Map<String, dynamic> j) {
    final savedAccounts = j['accounts'];
    if (savedAccounts is List) {
      accounts
        ..clear()
        ..addAll([
          for (final a in savedAccounts)
            UserAccount(
              name: a['name'] as String,
              email: a['email'] as String,
              salt: a['salt'] as String,
              passwordHash: a['passwordHash'] as String,
              createdAt: DateTime.parse(a['createdAt'] as String),
              emailVerified: (a['emailVerified'] as bool?) ?? false,
              phone: (a['phone'] as String?) ?? '',
              verifiedPhone: a['verifiedPhone'] as String?,
              address: (a['address'] as String?) ?? '',
              disabled: (a['disabled'] as bool?) ?? false,
            ),
        ]);
    }
    customerName = (j['customerName'] as String?) ?? customerName;
    customerEmail = (j['customerEmail'] as String?) ?? customerEmail;
    customerPhone = (j['customerPhone'] as String?) ?? customerPhone;
    customerAddress = (j['customerAddress'] as String?) ?? customerAddress;
    verifiedPhone = j['verifiedPhone'] as String?;
    emailVerified = (j['emailVerified'] as bool?) ?? emailVerified;
    isProvider = (j['isProvider'] as bool?) ?? isProvider;
    businessDescription = (j['businessDescription'] as String?) ?? businessDescription;
    businessLocation = (j['businessLocation'] as String?) ?? businessLocation;
    customerPhoto = _photoFromJson(j['customerPhoto']);
    _nextBookingNumber = (j['nextBooking'] as int?) ?? _nextBookingNumber;
    _nextServiceNumber = (j['nextService'] as int?) ?? _nextServiceNumber;
    _nextPaymentNumber = (j['nextPayment'] as int?) ?? _nextPaymentNumber;
    _nextPayoutNumber = (j['nextPayout'] as int?) ?? _nextPayoutNumber;
    commissionRate = (j['commissionRate'] as num?)?.toDouble() ?? kDefaultCommissionRate;
    final savedPayoutAccounts = j['payoutAccounts'];
    if (savedPayoutAccounts is Map) {
      _payoutAccounts
        ..clear()
        ..addAll({
          for (final e in savedPayoutAccounts.entries)
            e.key as String: PayoutAccount(
              bank: e.value['bank'] as String,
              accountType: e.value['accountType'] as String,
              holderName: e.value['holderName'] as String,
              accountNumber: e.value['accountNumber'] as String,
              branchCode: e.value['branchCode'] as String,
            ),
        });
    }
    final savedPayouts = j['payouts'];
    if (savedPayouts is List) {
      payouts
        ..clear()
        ..addAll([
          for (final p in savedPayouts)
            Payout(
              id: p['id'] as String,
              providerId: p['providerId'] as String,
              bookingId: p['bookingId'] as String,
              serviceName: p['serviceName'] as String,
              clientName: p['clientName'] as String,
              amount: p['amount'] as int,
              jobTotal: p['jobTotal'] as int?,
              commission: (p['commission'] as int?) ?? 0,
              createdAt: DateTime.parse(p['createdAt'] as String),
              status: _enumByName(PayoutStatus.values, p['status'], PayoutStatus.due),
              paidAt: p['paidAt'] == null ? null : DateTime.parse(p['paidAt'] as String),
              reference: p['reference'] as String?,
            ),
        ]);
    }

    // Businesses: sample ones are updated in place, new ones (approved
    // applications) are added back, and `me` stays the same object.
    final savedProviders = j['providers'];
    if (savedProviders is List) {
      final rebuilt = <ProviderModel>[];
      for (final raw in savedProviders) {
        if (raw is! Map) continue;
        final id = raw['id'] as String;
        ProviderModel? existing;
        for (final p in providers) {
          if (p.id == id) existing = p;
        }
        final p = existing ??
            ProviderModel(id: id, name: '', rating: 0, reviews: 0, distanceKm: 5, services: []);
        p
          ..name = raw['name'] as String
          ..rating = (raw['rating'] as num).toDouble()
          ..reviews = raw['reviews'] as int
          ..distanceKm = (raw['distanceKm'] as num).toDouble()
          ..latitude = (raw['latitude'] as num?)?.toDouble()
          ..longitude = (raw['longitude'] as num?)?.toDouble()
          ..verified = raw['verified'] as bool
          ..avatar = _photoFromJson(raw['avatar']);
        p.services
          ..clear()
          ..addAll([
            for (final s in (raw['services'] as List))
              ServiceModel(
                id: s['id'] as String,
                name: s['name'] as String,
                category: s['category'] as String,
                price: s['price'] as int,
                description: (s['description'] as String?) ?? '',
                rating: (s['rating'] as num?)?.toDouble(),
                active: (s['active'] as bool?) ?? true,
                photos: _photosFromJson(s['photos']),
                pricingType: s['pricingType'] == null
                    ? null
                    : _enumByName(PricingType.values, s['pricingType'], PricingType.hourly),
                packages: [
                  for (final k in ((s['packages'] as List?) ?? const []))
                    ServicePackage(
                      name: k['name'] as String,
                      price: k['price'] as int,
                      description: (k['description'] as String?) ?? '',
                    ),
                ],
              ),
          ]);
        rebuilt.add(p);
      }
      providers
        ..clear()
        ..addAll(rebuilt);
    }
    _providerOwner
      ..clear()
      ..addAll(Map<String, String>.from((j['owners'] as Map?) ?? const {}));
    final apps = j['applications'];
    if (apps is List) {
      providerApplications
        ..clear()
        ..addAll([
          for (final a in apps)
            ProviderApplicationRecord(
              id: a['id'] as String,
              businessName: a['businessName'] as String,
              email: a['email'] as String,
              services: a['services'] as String,
              description: (a['description'] as String?) ?? '',
              location: (a['location'] as String?) ?? '',
              appliedAt: DateTime.parse(a['appliedAt'] as String),
              registrationNumber: (a['registrationNumber'] as String?) ?? '',
              registrationDoc: _photoFromJson(a['registrationDoc']),
              idNumber: (a['idNumber'] as String?) ?? '',
              idDoc: _photoFromJson(a['idDoc']),
              applicantName: (a['applicantName'] as String?) ?? '',
              latitude: (a['latitude'] as num?)?.toDouble(),
              longitude: (a['longitude'] as num?)?.toDouble(),
              photos: _photosFromJson(a['photos']),
              mine: (a['mine'] as bool?) ?? false,
              status: _enumByName(ApplicationStatus.values, a['status'], ApplicationStatus.pending),
            )..rejectionReason = a['rejectionReason'] as String?,
        ]);
    }

    final saved = j['bookings'];
    if (saved is List) {
      _bookings
        ..clear()
        ..addAll([
          for (final b in saved)
            Booking(
              id: b['id'] as String,
              providerId: b['providerId'] as String,
              serviceId: b['serviceId'] as String,
              serviceName: b['serviceName'] as String,
              clientName: b['clientName'] as String,
              dateTime: DateTime.parse(b['dateTime'] as String),
              hours: (b['hours'] as int?) ?? 1,
              packageName: b['packageName'] as String?,
              price: b['price'] as int,
              bookingFee: b['bookingFee'] as int?,
              balancePaid: (b['balancePaid'] as bool?) ?? false,
              feeRefunded: (b['feeRefunded'] as bool?) ?? false,
              rating: b['rating'] as int?,
              review: b['review'] as String?,
              serviceMethod: b['serviceMethod'] == null
                  ? null
                  : _enumByName(PayMethod.values, b['serviceMethod'], PayMethod.card),
              completionPin: b['completionPin'] as String?,
              distanceKm: ((b['distanceKm'] as num?) ?? 0).toDouble(),
              phone: (b['phone'] as String?) ?? '',
              address: (b['address'] as String?) ?? '',
              notes: (b['notes'] as String?) ?? '',
              status: _enumByName(BookingStatus.values, b['status'], BookingStatus.pending),
            )
              ..latitude = (b['lat'] as num?)?.toDouble()
              ..longitude = (b['lng'] as num?)?.toDouble()
              ..pinAttempts = (b['pinAttempts'] as int?) ?? 0
              ..pinVerified = (b['pinVerified'] as bool?) ?? false,
        ]);
    }

    final pays = j['payments'];
    if (pays is List) {
      payments
        ..clear()
        ..addAll([
          for (final p in pays)
            PaymentRecord(
              id: p['id'] as String,
              bookingId: p['bookingId'] as String,
              kind: _enumByName(PaymentKind.values, p['kind'], PaymentKind.bookingFee),
              method: _enumByName(PayMethod.values, p['method'], PayMethod.card),
              amount: p['amount'] as int,
              createdAt: DateTime.parse(p['createdAt'] as String),
              gatewayReference: p['gatewayReference'] as String?,
              status: _enumByName(PaymentStatus.values, p['status'], PaymentStatus.paid),
              verified: (p['verified'] as bool?) ?? false,
            ),
        ]);
    }

    final chats = j['chats'];
    if (chats is Map) {
      _chats
        ..clear()
        ..addAll({
          for (final e in chats.entries)
            e.key as String: [
              for (final m in (e.value as List))
                ChatMessage(
                  text: m['text'] as String,
                  sentAt: DateTime.parse(m['sentAt'] as String),
                  fromProvider: m['fromProvider'] as bool,
                ),
            ],
        });
    }

    Map<String, List<String>> notes(dynamic raw) => {
          if (raw is Map)
            for (final e in raw.entries) e.key as String: List<String>.from(e.value as List),
        };
    Map<String, int> counts(dynamic raw) => {
          if (raw is Map) for (final e in raw.entries) e.key as String: e.value as int,
        };
    if (j['providerNotes'] != null) {
      _providerNotes
        ..clear()
        ..addAll(notes(j['providerNotes']));
      _providerUnread
        ..clear()
        ..addAll(counts(j['providerUnread']));
      _customerNotes
        ..clear()
        ..addAll(notes(j['customerNotes']));
      _customerUnread
        ..clear()
        ..addAll(counts(j['customerUnread']));
    }
    _updateDistances();
  }

  /// Reads the saved data (if any). Called once before the app starts.
  Future<void> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(kStorageKey);
      if (text != null) restoreFrom(jsonDecode(text) as Map<String, dynamic>);
    } catch (e) {
      // A damaged save must never block the app: start fresh instead.
      debugPrint('Could not restore saved data: $e');
    } finally {
      _persist = true;
    }
  }

  /// "Reset demo data": forgets everything saved; the app starts clean on the
  /// next launch.
  Future<void> clearSaved() async {
    _saveTimer?.cancel();
    _persist = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kStorageKey);
    } catch (_) {}
  }

  Future<void> _writeNow() async {
    if (!_persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kStorageKey, jsonEncode(toJson()));
    } catch (e) {
      debugPrint('Could not save data: $e');
    }
  }
}
