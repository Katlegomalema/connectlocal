import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';

/// A place on the map.
class GeoPoint {
  final double latitude;
  final double longitude;

  /// A readable address, when the service returned one.
  final String? label;
  const GeoPoint(this.latitude, this.longitude, {this.label});
}

/// A lookup that either found a place or says, in plain words, why not (to show to the person).
typedef GeoResult = ({GeoPoint? point, String? problem});

const _notFound = 'Couldn’t find that address. Try adding the suburb or city.';
const _noInternet = 'No internet connection. Check your connection and try again.';

/// Address search and "what is here?" go through OUR backend (GET /geo/search, /geo/reverse), which talks to
/// OpenStreetMap Nominatim with a proper app name, at most once per second, and caches the answers. Calling
/// Nominatim from every phone / browser got the app blocked (403).
ApiClient get _api => ApiClient.instance;

/// Turns an address typed by the person into map coordinates (South Africa).
Future<GeoResult> lookupAddress(String address) async {
  final query = address.trim();
  if (query.length < 3) return (point: null, problem: 'Type a longer address (street, suburb and city).');
  try {
    final uri = Uri(path: '/geo/search', queryParameters: {'q': query}).toString();
    final places = ApiClient.dataOf(await _api.get(uri, auth: false))['places'] as List? ?? const [];
    final first = places.isEmpty ? null : places.first as Map;
    if (first == null) return (point: null, problem: _notFound);
    return (
      point: GeoPoint((first['latitude'] as num).toDouble(), (first['longitude'] as num).toDouble(),
          label: first['label'] as String?),
      problem: null,
    );
  } on ApiException catch (e) {
    return (point: null, problem: e.isNetwork ? _noInternet : e.message);
  }
}

/// Map coordinates for an address, or null (use [lookupAddress] to also get the reason).
Future<GeoPoint?> geocodeAddress(String address) async => (await lookupAddress(address)).point;

/// Finds the address for a map spot (best effort: null when unknown or offline).
Future<String?> reverseGeocode(double lat, double lng) async {
  try {
    final uri = Uri(path: '/geo/reverse', queryParameters: {'lat': '$lat', 'lng': '$lng'}).toString();
    final place = ApiClient.dataOf(await _api.get(uri, auth: false))['place'] as Map?;
    return place?['label'] as String?;
  } on ApiException {
    return null;
  }
}

/// The phone's current position (asks for permission if needed), or why it is not available:
/// GPS off, permission refused, permission blocked for good, or no fix in time.
Future<GeoResult> findMyLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (
        point: null,
        problem: kIsWeb
            ? 'Location is switched off on this device. Turn it on, or type the address.'
            : 'Your phone’s location (GPS) is off. Turn it on in the quick settings, or type the address.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      return (
        point: null,
        problem: kIsWeb
            ? 'Location is blocked for this site. Click the lock icon in the address bar → Location → Allow, '
                'then try again. Or type the address.'
            : 'Location is blocked for ConnectLocal. Turn it on in Settings → Apps → ConnectLocal → Permissions → '
                'Location, or type the address.',
      );
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
      return (point: null, problem: 'ConnectLocal may not use your location. Tap "Allow" when asked, or type the address.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    final label = await reverseGeocode(position.latitude, position.longitude); // null offline: still a position
    return (point: GeoPoint(position.latitude, position.longitude, label: label), problem: null);
  } catch (_) {
    return (
      point: null,
      problem: 'We couldn’t get your location (weak GPS signal?). Try again, choose the spot on the map, or type the address.',
    );
  }
}

/// The phone's current position, or null (use [findMyLocation] to also get the reason).
Future<GeoPoint?> currentLocation() async => (await findMyLocation()).point;
