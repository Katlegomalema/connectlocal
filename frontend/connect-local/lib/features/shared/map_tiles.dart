import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Map tiles for every map in the app.
///
/// Default: OpenStreetMap's standard tiles (tile.openstreetmap.org). Free, no API key. Their tile policy asks
/// for (1) the attribution below, always visible, (2) a real app name in the User-Agent (Android/iOS: see
/// [userAgentPackageName]; web: the browser sends its own) and (3) light use: fine for testing and a demo.
/// (CARTO's basemaps, used before, now show "API KEY REQUIRED" on every tile.)
/// For heavy use switch to a paid provider:
///   --dart-define=MAP_TILE_URL=https://.../{z}/{x}/{y}.png --dart-define=MAP_ATTRIBUTION=...
class MapTiles {
  MapTiles._();

  static const urlTemplate = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// Only for URLs with {s}: OpenStreetMap asks apps NOT to use the old a./b./c. hosts.
  static List<String> get subdomains => urlTemplate.contains('{s}') ? const ['a', 'b', 'c', 'd'] : const [];
  static const attribution = String.fromEnvironment('MAP_ATTRIBUTION', defaultValue: '© OpenStreetMap contributors');

  /// Sent as "flutter_map (za.connectlocal.app)" on Android/iOS so tile servers know who we are
  /// (OpenStreetMap blocks the default "com.example" name).
  static const userAgentPackageName = 'za.connectlocal.app';

  /// OpenStreetMap draws tiles up to zoom 19; closer zooms enlarge those.
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

/// "© OpenStreetMap contributors" in a corner of the map (required by the tile policy).
class MapAttribution extends StatelessWidget {
  final AttributionAlignment alignment;
  const MapAttribution({super.key, this.alignment = AttributionAlignment.bottomRight});

  @override
  Widget build(BuildContext context) => RichAttributionWidget(
        alignment: alignment,
        attributions: const [TextSourceAttribution(MapTiles.attribution)],
      );
}
