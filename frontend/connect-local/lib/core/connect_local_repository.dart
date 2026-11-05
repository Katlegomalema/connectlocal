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
    // PostGIS point as GeoJSON: {"type":"Point","coordinates":[lng, lat]}
    final coordinates = (provider['location'] as Map?)?['coordinates'];
    return providerFromJson({
      ...provider,
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

  // ---- admin ---------------------------------------------------------------------------------------------
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
