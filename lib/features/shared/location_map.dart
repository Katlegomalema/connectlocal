import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

const _teal = Color(0xFF1F5FA8);
const _red = Color(0xFFE5251F);
const _hairline = Color(0xFFE5E7EB);

/// Opens the place in the phone's maps app (or the browser) with directions.
Future<bool> openDirections(BuildContext context, double lat, double lng) =>
    openDirectionsTo(context, lat: lat, lng: lng);

/// Opens turn-by-turn directions to a place given by coordinates, or by a
/// typed address when there are no coordinates. Used both ways: the customer
/// going to the provider's business, and the provider going to the customer.
Future<bool> openDirectionsTo(
  BuildContext context, {
  double? lat,
  double? lng,
  String? address,
}) async {
  final String destination;
  if (lat != null && lng != null) {
    destination = '$lat,$lng';
  } else if (address != null && address.trim().isNotEmpty) {
    destination = Uri.encodeComponent(address.trim());
  } else {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(duration: const Duration(seconds: 3), content: Text('No location has been added yet.')));
    return false;
  }
  final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination');
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(duration: const Duration(seconds: 3), content: Text('Couldn’t open maps on this device.')));
  }
  return ok;
}

/// A pin on the map.
class MapPin {
  final String id;
  final double latitude;
  final double longitude;
  final String label;
  const MapPin({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

/// OpenStreetMap view with one or more provider pins and (optionally) the
/// customer's own position. Tiles come from openstreetmap.org (free, no key).
///
/// For production traffic, OSM's tile server has a usage policy; switch the
/// [urlTemplate] to a hosted tile provider when the app is released.
class LocationMap extends StatelessWidget {
  final List<MapPin> pins;
  final String? selectedId;
  final ValueChanged<MapPin>? onPinTap;

  /// Customer position, shown as a blue dot.
  final double? userLatitude;
  final double? userLongitude;

  /// False = a fixed preview (no drag / zoom), e.g. on a profile page.
  final bool interactive;
  final double height;
  final VoidCallback? onTap;

  static const urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  const LocationMap({
    super.key,
    required this.pins,
    this.selectedId,
    this.onPinTap,
    this.userLatitude,
    this.userLongitude,
    this.interactive = true,
    this.height = 220,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      for (final p in pins) LatLng(p.latitude, p.longitude),
      if (userLatitude != null && userLongitude != null)
        LatLng(userLatitude!, userLongitude!),
    ];
    if (points.isEmpty) return const SizedBox.shrink();

    final MapOptions options = points.length == 1
        ? MapOptions(
            initialCenter: points.first,
            initialZoom: 15,
            interactionOptions: InteractionOptions(
              flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
            onTap: onTap == null ? null : (_, __) => onTap!(),
          )
        : MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(48),
              maxZoom: 15,
            ),
            interactionOptions: InteractionOptions(
              flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
            onTap: onTap == null ? null : (_, __) => onTap!(),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: _hairline),
          borderRadius: BorderRadius.circular(18),
        ),
        child: FlutterMap(
          options: options,
          children: [
            TileLayer(
              urlTemplate: urlTemplate,
              userAgentPackageName: 'com.example.connect_local',
            ),
            MarkerLayer(
              markers: [
                if (userLatitude != null && userLongitude != null)
                  Marker(
                    point: LatLng(userLatitude!, userLongitude!),
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0x40000000), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                for (final p in pins)
                  Marker(
                    point: LatLng(p.latitude, p.longitude),
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: onPinTap == null ? null : () => onPinTap!(p),
                      child: Icon(
                        Icons.location_on,
                        size: p.id == selectedId ? 48 : 40,
                        color: p.id == selectedId ? _red : _teal,
                        shadows: const [Shadow(color: Color(0x55000000), blurRadius: 6)],
                      ),
                    ),
                  ),
              ],
            ),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomRight,
              attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
            ),
          ],
        ),
      ),
    );
  }
}
