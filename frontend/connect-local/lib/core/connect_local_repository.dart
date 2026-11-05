import '../features/community/models/models.dart';
import '../features/shared/photo.dart';
import 'api_client.dart';

/// A category from the server (the list the app shows comes from here, not from built-in code).
class CategoryInfo {
  final String id;
  final String name;
  final String? icon;
  const CategoryInfo({required this.id, required this.name, this.icon});
}

/// The provider's own application, as the server sees it.
class MyApplication {
  final String providerId;
  final String businessName;

  /// draft | submitted | approved | rejected | suspended
  final String status;
  final String? rejectionReason;

  /// What is still needed before it can be submitted, e.g. ['id_document'].
  final List<String> missing;
  const MyApplication({
    required this.providerId,
    required this.businessName,
    required this.status,
    this.rejectionReason,
    this.missing = const [],
  });

  bool get isApproved => status == 'approved';
  bool get isWaiting => status == 'submitted';
}

/// Everything the app reads/writes for providers, services, applications and search, via the API.
///
/// Files (documents, photos) go straight to Supabase Storage with a one-time signed upload URL that the
/// backend hands out; documents land in a PRIVATE bucket (the admin sees them through short-lived links).
class ConnectLocalRepository {
  final ApiClient api;
  ConnectLocalRepository(this.api);

  Map<String, String> _categoryNames = const {}; // id -> name

  // ---- categories ---------------------------------------------------------------------------------------
  Future<List<CategoryInfo>> categories() async {
    final data = ApiClient.dataOf(await api.get('/search/categories', auth: false));
    final list = [
      for (final c in (data['categories'] as List? ?? const []))
        if (c is Map)
          CategoryInfo(id: c['id'] as String, name: c['name'] as String, icon: c['icon'] as String?),
    ];
    _categoryNames = {for (final c in list) c.id: c.name};
    return list;
  }

  // ---- search (customers) -------------------------------------------------------------------------------
  /// Verified providers with their active services. [query] / [category] filter on the server.
  Future<List<ProviderModel>> searchProviders({String query = '', String? category, int limit = 100}) async {
    if (_categoryNames.isEmpty) await categories();
    final params = <String, String>{
      'pageSize': '$limit',
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (category != null && category != 'ALL') 'category': category,
    };
    final uri = Uri(path: '/search/providers', queryParameters: params).toString();
    final data = ApiClient.dataOf(await api.get(uri, auth: false));
    return [
      for (final p in (data['providers'] as List? ?? const []))
        if (p is Map<String, dynamic>) providerFromJson(p),
    ];
  }

  ProviderModel providerFromJson(Map<String, dynamic> json) {
    final provider = ProviderModel(
      id: json['id'] as String,
      name: (json['business_name'] as String?) ?? '',
      rating: _toDouble(json['rating_average']) ?? 0,
      reviews: (json['rating_count'] as num?)?.toInt() ?? 0,
      distanceKm: _toDouble(json['distance_km']) ?? 0,
      distanceIsLive: json['distance_km'] != null,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      verified: json['verified'] == true || json['verification_status'] == 'verified',
      description: (json['business_description'] as String?) ?? (json['description'] as String?) ?? '',
      address: (json['street_address'] as String?) ?? '',
      services: [
        for (final s in (json['services'] as List? ?? const []))
          if (s is Map<String, dynamic>) serviceFromJson(s),
      ],
    );
    final photo = json['photoUrl'] as String?;
    if (photo != null) provider.avatar = PhotoRef(url: photo, name: 'photo.jpg');
    return provider;
  }

  ServiceModel serviceFromJson(Map<String, dynamic> json) {
    final pricing = switch (json['pricing_type']) {
      'hourly' => PricingType.hourly,
      'package' => PricingType.packages,
      _ => PricingType.fixed,
    };
    final packages = [
      for (final p in (json['packages'] as List? ?? const []))
        if (p is Map && p['is_active'] != false)
          ServicePackage(
            name: (p['name'] as String?) ?? '',
            price: (_toDouble(p['price']) ?? 0).round(),
            description: (p['description'] as String?) ?? '',
          ),
    ]..sort((a, b) => a.price.compareTo(b.price));
    final basePrice = (_toDouble(json['base_price']) ?? 0).round();
    return ServiceModel(
      id: json['id'] as String,
      name: (json['service_name'] as String?) ?? '',
      category: _categoryNames[json['category_id']] ?? (json['category'] as String?) ?? '',
      price: pricing == PricingType.packages && packages.isNotEmpty ? packages.first.price : basePrice,
      description: (json['description'] as String?) ?? '',
      active: json['active'] != false,
      pricingType: pricing,
      packages: packages,
      photos: [
        for (final ph in (json['photos'] as List? ?? const []))
          if (ph is Map && ph['url'] is String) PhotoRef(url: ph['url'] as String, name: 'photo.jpg'),
      ],
    )..serverPackageIds.addAll({
        for (final p in (json['packages'] as List? ?? const []))
          if (p is Map && p['is_active'] != false && p['id'] is String) (p['name'] as String? ?? ''): p['id'] as String,
      });
  }

  // ---- files ---------------------------------------------------------------------------------------------
  static String contentTypeFor(PhotoRef file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Uploads [file] and returns its storage path (and public URL for photos).
  Future<({String path, String? publicUrl})> upload(PhotoRef file, {required bool document}) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw const ApiException('Please pick the file again (it is no longer available on this device).');
    }
    final contentType = contentTypeFor(file);
    final data = ApiClient.dataOf(await api.post('/uploads/sign', body: {
      'purpose': document ? 'provider_document' : 'provider_photo',
      'contentType': contentType,
    }));
    final maxBytes = (data['maxBytes'] as num?)?.toInt();
    if (maxBytes != null && bytes.length > maxBytes) {
      throw ApiException('That file is too big (max ${maxBytes ~/ (1024 * 1024)} MB).', code: 'FILE_TOO_LARGE');
    }
    await api.putBytes(data['uploadUrl'] as String, bytes, contentType);
    return (path: data['path'] as String, publicUrl: data['publicUrl'] as String?);
  }

  // ---- provider application -------------------------------------------------------------------------------
  /// Null when this account has no business profile yet.
  Future<MyApplication?> myApplication() async {
    try {
      final data = ApiClient.dataOf(await api.get('/providers/me/application'));
      final a = (data['application'] as Map?)?.cast<String, dynamic>() ?? const {};
      return MyApplication(
        providerId: a['id'] as String,
        businessName: (a['businessName'] as String?) ?? '',
        status: (a['status'] as String?) ?? 'draft',
        rejectionReason: a['rejectionReason'] as String?,
        missing: [for (final m in (a['missing'] as List? ?? const [])) '$m'],
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// The whole "Become a provider" form: profile, documents, photos, then submit for review.
  /// Safe to call again after a failure or a rejection (the profile is updated instead of created).
  Future<MyApplication> submitApplication({
    required String businessName,
    required String category,
    required String description,
    required String address,
    required String registrationNumber,
    required double latitude,
    required double longitude,
    required PhotoRef registrationDoc,
    required PhotoRef idDoc,
    List<PhotoRef> photos = const [],
  }) async {
    final profile = {
      'businessName': businessName,
      'category': category,
      'description': description,
      'streetAddress': address.length > 150 ? address.substring(0, 150) : address,
      'registrationNumber': registrationNumber,
      'location': {'lat': latitude, 'lng': longitude},
    };
    final existing = await myApplication();
    if (existing == null) {
      await api.post('/providers', body: profile);
    } else if (!existing.isApproved) {
      await api.patch('/providers/me', body: profile);
    }

    for (final (type, file) in [('registration_certificate', registrationDoc), ('id_document', idDoc)]) {
      final uploaded = await upload(file, document: true);
      await api.post('/providers/me/documents', body: {'documentType': type, 'storagePath': uploaded.path});
    }
    for (final photo in photos.where((p) => p.isLocal)) {
      final uploaded = await upload(photo, document: false);
      await api.post('/providers/me/photos', body: {'storagePath': uploaded.path});
    }

    await api.post('/providers/me/application/submit');
    return (await myApplication())!;
  }

  /// The signed-in provider's own business (with all their services, active or not).
  Future<ProviderModel?> myBusiness() async {
    final Map<String, dynamic> provider;
    try {
      provider = (ApiClient.dataOf(await api.get('/providers/me'))['provider'] as Map).cast<String, dynamic>();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
    if (_categoryNames.isEmpty) await categories();
    final services = ApiClient.dataOf(await api.get('/providers/me/services'))['services'] as List? ?? const [];
    // The API answers {"latitude": .., "longitude": ..} (older answers: GeoJSON coordinates [lng, lat]).
    final location = provider['location'];
    final coordinates = location is Map ? location['coordinates'] : null;
    return providerFromJson({
      ...provider,
      if (location is Map && location['latitude'] != null) 'latitude': location['latitude'],
      if (location is Map && location['longitude'] != null) 'longitude': location['longitude'],
      if (coordinates is List && coordinates.length >= 2) 'latitude': coordinates[1],
      if (coordinates is List && coordinates.length >= 2) 'longitude': coordinates[0],
      'services': services,
    });
  }

  // ---- services (provider) --------------------------------------------------------------------------------
  static String pricingName(PricingType type) => switch (type) {
        PricingType.hourly => 'hourly',
        PricingType.fixed => 'fixed',
        PricingType.packages => 'package',
      };

  /// Creates or updates a service, its packages and new photos. Returns the service id.
  Future<String> saveService({
    String? serviceId,
    required String name,
    required String category,
    required int price,
    required String description,
    required PricingType pricingType,
    List<ServicePackage> packages = const [],
    Map<String, String> existingPackageIds = const {},
    List<PhotoRef> photos = const [],
    int durationMinutes = 60,
  }) async {
    final body = {
      'title': name,
      'category': category,
      'description': description,
      'price': pricingType == PricingType.packages && packages.isNotEmpty
          ? packages.map((p) => p.price).reduce((a, b) => a < b ? a : b)
          : price,
      'durationMinutes': durationMinutes,
      'pricingType': pricingName(pricingType),
    };
    final String id;
    if (serviceId == null) {
      final data = ApiClient.dataOf(await api.post('/providers/me/services', body: body));
      id = (data['service'] as Map)['id'] as String;
    } else {
      await api.patch('/providers/me/services/$serviceId', body: body);
      id = serviceId;
    }

    if (pricingType == PricingType.packages) {
      final keep = <String>{};
      for (final pkg in packages) {
        final packageBody = {'name': pkg.name, 'price': pkg.price, 'description': pkg.description};
        final known = existingPackageIds[pkg.name];
        if (known != null) {
          keep.add(known);
          await api.patch('/providers/me/services/$id/packages/$known', body: packageBody);
        } else {
          await api.post('/providers/me/services/$id/packages', body: packageBody);
        }
      }
      for (final entry in existingPackageIds.entries) {
        if (!keep.contains(entry.value)) await api.delete('/providers/me/services/$id/packages/${entry.value}');
      }
    }
    for (final photo in photos.where((p) => p.isLocal)) {
      final uploaded = await upload(photo, document: false);
      await api.post('/providers/me/services/$id/photos', body: {'storagePath': uploaded.path});
    }
    return id;
  }

  Future<void> setServiceActive(String serviceId, bool active) =>
      api.patch('/providers/me/services/$serviceId', body: {'isActive': active});

  // ---- bookings ------------------------------------------------------------------------------------------
  /// Creates a booking request (status pending, 15% fee still to pay). Returns the server booking.
  Future<Map<String, dynamic>> createBooking({
    required String providerId,
    required String serviceId,
    required DateTime scheduledStart,
    required String address,
    int? hours,
    String? packageId,
    double? latitude,
    double? longitude,
    String notes = '',
  }) async {
    final data = ApiClient.dataOf(await api.post('/bookings', body: {
      'providerId': providerId,
      'serviceId': serviceId,
      'scheduledStart': scheduledStart.toUtc().toIso8601String(),
      'address': address,
      'hours': ?hours,
      'packageId': ?packageId,
      if (latitude != null && longitude != null) 'latitude': latitude,
      if (latitude != null && longitude != null) 'longitude': longitude,
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    }));
    return data;
  }

  /// The signed-in person's bookings (customer: theirs; provider: made with their business).
  Future<List<Map<String, dynamic>>> myBookings() async {
    final data = ApiClient.dataOf(await api.get('/bookings?limit=100'));
    return [
      for (final b in (data['bookings'] as List? ?? const []))
        if (b is Map<String, dynamic>) b,
    ];
  }

  Future<Map<String, dynamic>> booking(String id) async => ApiClient.dataOf(await api.get('/bookings/$id'));

  Future<Map<String, dynamic>> accept(String id) async => ApiClient.dataOf(await api.post('/bookings/$id/accept'));

  Future<Map<String, dynamic>> decline(String id, {String? reason}) async =>
      ApiClient.dataOf(await api.post('/bookings/$id/decline', body: {'reason': ?reason}));

  Future<Map<String, dynamic>> cancel(String id, {String? reason}) async =>
      ApiClient.dataOf(await api.post('/bookings/$id/cancel', body: {'reason': ?reason}));

  /// Provider enters the customer's PIN on arrival (checked on the server, 5 tries).
  Future<Map<String, dynamic>> startWithPin(String id, String pin) async =>
      ApiClient.dataOf(await api.post('/bookings/$id/start', body: {'pin': pin}));

  Future<Map<String, dynamic>> complete(String id) async => ApiClient.dataOf(await api.post('/bookings/$id/complete'));

  /// Provider confirms the customer paid the balance in cash.
  Future<void> confirmCash(String id) => api.post('/bookings/$id/balance/cash');

  /// Customer only, once accepted: the 4-digit PIN to give the provider.
  Future<String?> arrivalPin(String id) async {
    try {
      return ApiClient.dataOf(await api.get('/bookings/$id/arrival-pin'))['pin'] as String?;
    } on ApiException catch (e) {
      if (e.statusCode == 409 || e.statusCode == 403) return null;
      rethrow;
    }
  }

  Future<void> review(String bookingId, int rating, String comment) => api.post('/reviews', body: {
        'bookingId': bookingId,
        'rating': rating,
        if (comment.trim().isNotEmpty) 'comment': comment.trim(),
      });

  // ---- payouts ------------------------------------------------------------------------------------------
  /// The provider's bank details as the server shows them (only the last 4 digits), or null.
  Future<Map<String, dynamic>?> payoutDetails() async =>
      (ApiClient.dataOf(await api.get('/providers/me/payout-details'))['payoutDetails'] as Map?)?.cast<String, dynamic>();

  /// Sends the full account number once; the server stores it encrypted and returns the masked details.
  Future<Map<String, dynamic>> savePayoutDetails({
    required String bankName,
    required String accountType,
    required String accountHolderName,
    required String accountNumber,
    required String branchCode,
  }) async =>
      (ApiClient.dataOf(await api.put('/providers/me/payout-details', body: {
        'bankName': bankName,
        'accountType': accountType,
        'accountHolderName': accountHolderName,
        'accountNumber': accountNumber,
        'branchCode': branchCode,
      }))['payoutDetails'] as Map)
          .cast<String, dynamic>();

  Future<List<Map<String, dynamic>>> myPayouts() async => [
        for (final p in (ApiClient.dataOf(await api.get('/providers/me/payouts'))['payouts'] as List? ?? const []))
          if (p is Map<String, dynamic>) p,
      ];

  /// Customer chooses to pay the balance in cash (saved on the server).
  Future<Map<String, dynamic>> chooseCash(String bookingId) async =>
      ApiClient.dataOf(await api.post('/bookings/$bookingId/balance/cash-choice'));

  // ---- payments (PayFast) ----------------------------------------------------------------------------------
  /// Starts a card payment. [purpose]: 'booking_fee' or 'balance'. Open [checkoutUrl] in a browser,
  /// then poll [paymentStatus] until it is paid or failed.
  Future<({String paymentId, String checkoutUrl, double amount, bool sandbox})> startPayment(
      String bookingId, String purpose) async {
    final data = ApiClient.dataOf(await api.post('/payments/intent', body: {'bookingId': bookingId, 'purpose': purpose}));
    return (
      paymentId: data['paymentId'] as String,
      checkoutUrl: data['checkoutUrl'] as String,
      amount: _toDouble(data['amount']) ?? 0,
      sandbox: data['sandbox'] == true,
    );
  }

  /// pending | paid | failed | refunded (+ PayFast's reference once paid).
  Future<({String status, String? reference})> paymentStatus(String paymentId) async {
    final data = ApiClient.dataOf(await api.get('/payments/$paymentId'));
    return (status: (data['payment_status'] as String?) ?? 'pending', reference: data['transaction_reference'] as String?);
  }

  /// The signed-in person's payments (fees and balances).
  Future<List<PaymentRecord>> myPayments() async {
    final data = ApiClient.dataOf(await api.get('/payments?limit=100'));
    return [
      for (final p in (data['payments'] as List? ?? const []))
        if (p is Map<String, dynamic>)
          paymentFromJson({
            ...p,
            'status': p['payment_status'],
            'bookingId': p['booking_id'],
            'reference': p['transaction_reference'],
            'createdAt': p['created_at'],
          }),
    ];
  }

  static PaymentRecord paymentFromJson(Map<String, dynamic> p) => PaymentRecord(
        id: p['id'] as String,
        bookingId: p['bookingId'] as String,
        kind: p['purpose'] == 'balance' ? PaymentKind.service : PaymentKind.bookingFee,
        method: p['method'] == 'cash' ? PayMethod.cash : PayMethod.card,
        amount: _toDouble(p['amount']) ?? 0,
        createdAt: _date(p['createdAt']) ?? DateTime.now(),
        gatewayReference: p['reference'] as String?,
        status: switch (p['status']) {
          'paid' => PaymentStatus.paid,
          'failed' => PaymentStatus.failed,
          'refunded' || 'partially_refunded' => PaymentStatus.refunded,
          _ => PaymentStatus.pending,
        },
        verified: p['status'] == 'paid' || p['status'] == 'refunded',
        serviceName: p['serviceName'] as String?,
        customerName: p['customerName'] as String?,
        businessName: p['businessName'] as String?,
      );

  // ---- profile -------------------------------------------------------------------------------------------
  Future<void> updateMyName(String userId, String fullName) =>
      api.put('/users/$userId', body: {'fullName': fullName});

  /// Business name, description, address and map point.
  Future<void> updateMyBusiness({
    required String name,
    required String description,
    required String address,
    double? latitude,
    double? longitude,
  }) =>
      api.patch('/providers/me', body: {
        if (name.trim().length >= 2) 'businessName': name.trim(),
        'description': description.trim(),
        'streetAddress': address.length > 150 ? address.substring(0, 150) : address,
        if (latitude != null && longitude != null) 'location': {'lat': latitude, 'lng': longitude},
      });

  /// Adds a photo to the business (the newest photo is the one customers see first).
  Future<String?> addBusinessPhoto(PhotoRef photo) async {
    final uploaded = await upload(photo, document: false);
    await api.post('/providers/me/photos', body: {'storagePath': uploaded.path});
    return uploaded.publicUrl;
  }

  // ---- notifications -------------------------------------------------------------------------------------
  Future<List<AppNotification>> notifications() async {
    final data = ApiClient.dataOf(await api.get('/notifications?limit=50'));
    return [
      for (final n in (data['notifications'] as List? ?? const []))
        if (n is Map<String, dynamic>)
          AppNotification(
            id: n['id'] as String,
            title: (n['title'] as String?) ?? '',
            body: (n['message'] as String?) ?? '',
            type: (n['notification_type'] as String?) ?? 'system',
            createdAt: _date(n['created_at']) ?? DateTime.now(),
            bookingId: n['related_entity_type'] == 'booking' ? n['related_entity_id'] as String? : null,
            isRead: n['is_read'] == true,
          ),
    ];
  }

  Future<void> markAllNotificationsRead() => api.patch('/notifications/read-all');

  // ---- messages (one chat per booking) --------------------------------------------------------------------
  /// The booking's chat, oldest first. Opening it marks what you received as read.
  Future<List<ChatMessage>> bookingMessages(String bookingId) async {
    final data = ApiClient.dataOf(await api.get('/messages/booking/$bookingId'));
    return [
      for (final m in (data['messages'] as List? ?? const []))
        if (m is Map<String, dynamic>) _messageFromJson(m),
    ];
  }

  Future<ChatMessage> sendMessage(String bookingId, String text) async =>
      _messageFromJson(ApiClient.dataOf(await api.post('/messages', body: {'bookingId': bookingId, 'body': text})));

  /// Latest message + unread count for each booking chat.
  Future<List<ConversationSummary>> conversations() async {
    final data = ApiClient.dataOf(await api.get('/messages/conversations?limit=100'));
    return [
      for (final c in (data['conversations'] as List? ?? const []))
        if (c is Map && c['booking_id'] is String)
          ConversationSummary(
            bookingId: c['booking_id'] as String,
            lastMessage: (c['last_message'] as String?) ?? '',
            lastAt: _date(c['last_message_at']) ?? DateTime.now(),
            lastMine: c['last_message_mine'] == true,
            unread: (c['unread_count'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  static ChatMessage _messageFromJson(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        text: (m['text'] as String?) ?? '',
        sentAt: _date(m['sentAt']) ?? DateTime.now(),
        mine: m['mine'] == true,
        isRead: m['isRead'] == true,
      );

  // ---- reviews -------------------------------------------------------------------------------------------
  /// Public reviews of a provider, newest first.
  Future<List<ReviewItem>> providerReviews(String providerId) async {
    final data = ApiClient.dataOf(await api.get('/reviews/$providerId?limit=50', auth: false));
    return [
      for (final r in (data['reviews'] as List? ?? const []))
        if (r is Map<String, dynamic>)
          ReviewItem(
            id: r['id'] as String,
            rating: (r['rating'] as num?)?.toInt() ?? 0,
            comment: (r['comment'] as String?) ?? '',
            customerFirstName: (r['customerFirstName'] as String?) ?? 'Customer',
            serviceName: (r['serviceName'] as String?) ?? '',
            createdAt: _date(r['createdAt']) ?? DateTime.now(),
            providerResponse: r['providerResponse'] as String?,
          ),
    ];
  }

  // ---- admin ---------------------------------------------------------------------------------------------
  Future<Map<String, dynamic>> adminAnalytics() async => ApiClient.dataOf(await api.get('/admin/analytics'));

  Future<List<AdminUser>> adminUsers() async {
    final data = ApiClient.dataOf(await api.get('/admin/users?limit=100'));
    return [
      for (final u in (data['users'] as List? ?? const []))
        if (u is Map<String, dynamic>)
          AdminUser(
            id: u['id'] as String,
            name: (u['fullName'] as String?) ?? '',
            email: (u['email'] as String?) ?? '',
            role: (u['role'] as String?) ?? 'customer',
            status: (u['status'] as String?) ?? 'active',
            createdAt: _date(u['createdAt']) ?? DateTime.now(),
            businessName: (u['business'] as Map?)?['name'] as String?,
            businessStatus: (u['business'] as Map?)?['verificationStatus'] as String?,
          ),
    ];
  }

  /// [status]: active | suspended.
  Future<void> setUserStatus(String userId, String status) => api.put('/admin/users/$userId', body: {'status': status});

  /// Every booking (raw server rows, the app turns them into [Booking]s).
  Future<List<Map<String, dynamic>>> adminBookings() async => [
        for (final b in (ApiClient.dataOf(await api.get('/admin/bookings?limit=100'))['bookings'] as List? ?? const []))
          if (b is Map<String, dynamic>) b,
      ];

  Future<List<PaymentRecord>> adminPayments() async => [
        for (final p in (ApiClient.dataOf(await api.get('/admin/payments?limit=100'))['payments'] as List? ?? const []))
          if (p is Map<String, dynamic>) paymentFromJson(p),
      ];

  Future<List<Payout>> adminPayouts() async => [
        for (final p in (ApiClient.dataOf(await api.get('/admin/payouts?limit=100'))['payouts'] as List? ?? const []))
          if (p is Map<String, dynamic>) payoutFromJson(p),
      ];

  /// Provider's own (/providers/me/payouts) and admin (/admin/payouts) payouts share these fields.
  static Payout payoutFromJson(Map<String, dynamic> r, {String? providerId}) {
    final bank = r['bank'] as Map?;
    return Payout(
      id: r['id'] as String,
      providerId: providerId ?? (r['providerId'] as String?) ?? '',
      bookingId: r['bookingId'] as String,
      serviceName: (r['serviceName'] as String?) ?? 'Service',
      clientName: (r['customerName'] as String?) ?? '',
      amount: _toDouble(r['payoutAmount']) ?? 0,
      jobTotal: _toDouble(r['grossAmount']),
      commission: _toDouble(r['commissionAmount']) ?? 0,
      createdAt: _date(r['createdAt']) ?? DateTime.now(),
      status: r['status'] == 'paid' ? PayoutStatus.paid : PayoutStatus.due,
      paidAt: _date(r['paidAt']),
      reference: r['reference'] as String?,
      businessName: r['businessName'] as String?,
      note: r['note'] as String?,
      bankLabel: bank == null
          ? null
          : '${bank['bankName']} · ${bank['accountType']}\n${bank['accountHolderName']}\n'
              'Account \u2022\u2022\u2022\u2022 ${bank['accountLast4']} · Branch ${bank['branchCode']}',
    );
  }

  static DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

  // ---- admin: applications ---------------------------------------------------------------------------------
  /// Applications for the admin website. [status]: pending | verified | rejected.
  Future<List<ProviderApplicationRecord>> applications({String status = 'pending'}) async {
    final data = ApiClient.dataOf(await api.get('/admin/providers/pending?status=$status&limit=100'));
    final appStatus = switch (status) {
      'verified' => ApplicationStatus.approved,
      'rejected' => ApplicationStatus.rejected,
      _ => ApplicationStatus.pending,
    };
    return [
      for (final p in (data['providers'] as List? ?? const []))
        if (p is Map<String, dynamic>) _applicationFromJson(p, appStatus),
    ];
  }

  ProviderApplicationRecord _applicationFromJson(Map<String, dynamic> json, ApplicationStatus status) {
    PhotoRef? doc(String type) {
      for (final d in (json['documents'] as List? ?? const [])) {
        if (d is Map && d['documentType'] == type && d['url'] is String) {
          final url = d['url'] as String;
          // The name decides how the app shows it (PDF icon vs picture).
          final isPdf = Uri.tryParse(url)?.path.toLowerCase().endsWith('.pdf') ?? false;
          return PhotoRef(url: url, name: isPdf ? '$type.pdf' : '$type.jpg');
        }
      }
      return null;
    }

    final applicant = (json['applicant'] as Map?) ?? const {};
    final location = (json['location'] as Map?) ?? const {};
    final record = ProviderApplicationRecord(
      id: json['id'] as String,
      businessName: (json['businessName'] as String?) ?? '',
      email: (applicant['email'] as String?) ?? '',
      applicantName: (applicant['fullName'] as String?) ?? '',
      services: (json['category'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      location: (json['address'] as String?) ?? '',
      registrationNumber: (json['registrationNumber'] as String?) ?? '',
      registrationDoc: doc('registration_certificate'),
      idDoc: doc('id_document'),
      // The ID number is not stored on the server (privacy): the admin checks it on the ID document.
      idNumber: '',
      latitude: _toDouble(location['latitude']),
      longitude: _toDouble(location['longitude']),
      photos: [
        for (final ph in (json['photos'] as List? ?? const []))
          if (ph is Map && ph['url'] is String) PhotoRef(url: ph['url'] as String, name: 'photo.jpg'),
      ],
      appliedAt: DateTime.tryParse((json['submittedAt'] as String?) ?? '') ?? DateTime.now(),
      status: status,
    );
    record.rejectionReason = json['rejectionReason'] as String?;
    return record;
  }

  Future<void> approve(String providerId) => api.post('/admin/providers/$providerId/verify');

  Future<void> reject(String providerId, String reason) =>
      api.post('/admin/providers/$providerId/reject', body: {'reason': reason});

  static double? _toDouble(Object? value) => switch (value) {
        num n => n.toDouble(),
        String s => double.tryParse(s),
        _ => null,
      };
}
