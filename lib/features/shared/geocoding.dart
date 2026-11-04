import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// A place on the map.
class GeoPoint {
  final double latitude;
  final double longitude;

  /// A readable address, when the service returned one.
  final String? label;
  const GeoPoint(this.latitude, this.longitude, {this.label});
}

const _host = 'nominatim.openstreetmap.org';
const _headers = {
  'Accept-Language': 'en',
  // Nominatim asks every app to identify itself (ignored by browsers).
  'User-Agent': 'ConnectLocal/1.0 (school project)',
};

/// Turns an address typed by the person into map coordinates using
/// OpenStreetMap's free Nominatim search (South Africa only). Returns null when
/// nothing matches or there is no connection.
/// Please keep usage light (max ~1 request per second).
Future<GeoPoint?> geocodeAddress(String address) async {
  final query = address.trim();
  if (query.isEmpty) return null;
  try {
    final uri = Uri.https(_host, '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
      'countrycodes': 'za',
    });
    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final list = jsonDecode(response.body) as List<dynamic>;
    if (list.isEmpty) return null;
    final first = list.first as Map<String, dynamic>;
    return GeoPoint(
      double.parse(first['lat'] as String),
      double.parse(first['lon'] as String),
      label: first['display_name'] as String?,
    );
  } catch (_) {
    return null;
  }
}

/// Finds the address for a GPS position (best effort).
Future<String?> reverseGeocode(double lat, double lng) async {
  try {
    final uri = Uri.https(_host, '/reverse', {
      'lat': '$lat',
      'lon': '$lng',
      'format': 'json',
      'zoom': '16',
    });
    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['display_name'] as String?;
  } catch (_) {
    return null;
  }
}

/// The phone's current position, asking for permission if needed. Returns null
/// if location is off or the person said no.
Future<GeoPoint?> currentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    final label = await reverseGeocode(position.latitude, position.longitude);
    return GeoPoint(position.latitude, position.longitude, label: label);
  } catch (_) {
    return null;
  }
}
