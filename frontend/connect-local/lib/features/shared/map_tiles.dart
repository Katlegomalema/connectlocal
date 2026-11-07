import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Map tiles for every map in the app.
///
/// Default: Esri "World Street Map" raster tiles. No API key; the attribution below must stay visible.
/// With a free MapTiler key (maptiler.com, no credit card, non-commercial use) the app uses MapTiler instead:
///   --dart-define=MAPTILER_KEY=...        (tool/run_web_codespace.sh passes $MAPTILER_KEY)
/// Any other provider: --dart-define=MAP_TILE_URL=https://.../{z}/{x}/{y}.png --dart-define=MAP_ATTRIBUTION=...
///
/// Not used any more: CARTO basemaps (now show "API KEY REQUIRED") and tile.openstreetmap.org (volunteer
/// servers that block apps without notice: "Access blocked").
class MapTiles {
  MapTiles._();

  static const _mapTilerKey = String.fromEnvironment('MAPTILER_KEY');
  static const _customUrl = String.fromEnvironment('MAP_TILE_URL');
  static const _customAttribution = String.fromEnvironment('MAP_ATTRIBUTION');

  static const esriUrl = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
  static const esriAttribution =
      'Tiles © Esri. Sources: Esri, HERE, Garmin, USGS, © OpenStreetMap contributors, GIS User Community';
  static const mapTilerAttribution = '© MapTiler © OpenStreetMap contributors';

  static String get urlTemplate {
    if (_customUrl.isNotEmpty) return _customUrl;
    if (_mapTilerKey.isNotEmpty) return 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=$_mapTilerKey';
    return esriUrl;
  }

  static String get attribution {
    if (_customAttribution.isNotEmpty) return _customAttribution;
    if (_customUrl.isEmpty && _mapTilerKey.isNotEmpty) return mapTilerAttribution;
    return _customUrl.isEmpty ? esriAttribution : '© OpenStreetMap contributors';
  }

  /// Only for URLs with {s} (several hosts a/b/c/d).
  static List<String> get subdomains => urlTemplate.contains('{s}') ? const ['a', 'b', 'c', 'd'] : const [];

  /// Sent as "flutter_map (za.connectlocal.app)" on Android/iOS so tile servers know who we are.
  static const userAgentPackageName = 'za.connectlocal.app';

  /// Deepest zoom the server draws; closer zooms enlarge those tiles.
  static const maxNativeZoom = int.fromEnvironment('MAP_MAX_NATIVE_ZOOM', defaultValue: 19);
}

/// The tile layer + a friendly message (with Retry) when tiles can't load, e.g. no internet.
class MapTileLayer extends StatefulWidget {
  const MapTileLayer({super.key});

  @override
  State<MapTileLayer> createState() => _MapTileLayerState();
}

class _MapTileLayerState extends State<MapTileLayer> {
  bool _failed = false;
  int _attempt = 0;

  void _tileFailed(TileImage tile, Object error, StackTrace? stackTrace) {
    if (!_failed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _failed = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          TileLayer(
            key: ValueKey(_attempt), // Retry: a fresh layer loads every tile again
            urlTemplate: MapTiles.urlTemplate,
            subdomains: MapTiles.subdomains,
            userAgentPackageName: MapTiles.userAgentPackageName,
            // Only servers with real @2x tiles ({r}); otherwise flutter_map would load 4x as many tiles.
            retinaMode: MapTiles.urlTemplate.contains('{r}') && RetinaMode.isHighDensity(context),
            maxNativeZoom: MapTiles.maxNativeZoom,
            errorTileCallback: _tileFailed,
          ),
          if (_failed)
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: Material(
                color: Colors.white.withValues(alpha: 0.95),
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 20, color: Colors.black54),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('The map can’t load. Check your internet connection.',
                            style: TextStyle(fontSize: 13, color: Colors.black87)),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _failed = false;
                          _attempt++;
                        }),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
}

/// The map credit (e.g. "Tiles © Esri ...") in a corner of the map (required).
class MapAttribution extends StatelessWidget {
  final AttributionAlignment alignment;
  const MapAttribution({super.key, this.alignment = AttributionAlignment.bottomRight});

  @override
  Widget build(BuildContext context) => RichAttributionWidget(
        alignment: alignment,
        attributions: [TextSourceAttribution(MapTiles.attribution)],
      );
}
