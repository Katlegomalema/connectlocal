import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Map tiles for every map in the app.
///
/// Default: CARTO "Voyager" raster tiles (OpenStreetMap data). Free for non-commercial use without an API key,
/// and they allow apps and web pages (tile.openstreetmap.org does not want apps to use it as their tile
/// server, and blocks apps that send a "com.example" name). The attribution below is REQUIRED by both.
/// Another provider: --dart-define=MAP_TILE_URL=https://.../{z}/{x}/{y}.png --dart-define=MAP_ATTRIBUTION=...
class MapTiles {
  MapTiles._();

  static const urlTemplate = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
  );
  static const subdomains = ['a', 'b', 'c', 'd'];
  static const attribution =
      String.fromEnvironment('MAP_ATTRIBUTION', defaultValue: '© OpenStreetMap contributors © CARTO');

  /// Sent as "flutter_map (za.connectlocal.app)" on Android/iOS so tile servers know who we are.
  static const userAgentPackageName = 'za.connectlocal.app';
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
            retinaMode: RetinaMode.isHighDensity(context),
            maxNativeZoom: 20,
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

/// "© OpenStreetMap contributors © CARTO" in a corner of the map (required).
class MapAttribution extends StatelessWidget {
  final AttributionAlignment alignment;
  const MapAttribution({super.key, this.alignment = AttributionAlignment.bottomRight});

  @override
  Widget build(BuildContext context) => RichAttributionWidget(
        alignment: alignment,
        attributions: const [TextSourceAttribution(MapTiles.attribution)],
      );
}
