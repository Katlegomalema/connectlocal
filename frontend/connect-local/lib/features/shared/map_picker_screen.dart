import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_tiles.dart';

import 'geocoding.dart';

const _blue = Color(0xFF1F5FA8);
const _red = Color(0xFFE5251F);

/// Lets the person choose a spot on the map: drag the map under the pin, tap
/// the map, search an address, or use their current location. Returns the
/// chosen [GeoPoint] (with a readable address when one could be found), or
/// null if they backed out.
Future<GeoPoint?> pickOnMap(
  BuildContext context, {
  GeoPoint? initial,
  String title = 'Choose location',
}) =>
    Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(builder: (_) => MapPickerScreen(initial: initial, title: title)),
    );

class MapPickerScreen extends StatefulWidget {
  final GeoPoint? initial;
  final String title;
  const MapPickerScreen({super.key, this.initial, this.title = 'Choose location'});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Pretoria, used until the person picks or finds a spot.
  static const _fallback = LatLng(-25.7479, 28.2293);

  final MapController _map = MapController();
  final TextEditingController _search = TextEditingController();
  late LatLng _center = widget.initial == null
      ? _fallback
      : LatLng(widget.initial!.latitude, widget.initial!.longitude);
  String? _label;
  bool _busy = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _label = widget.initial?.label;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  void _moved(LatLng center) {
    _center = center;
    _debounce?.cancel();
    // Only after the map stopped moving for a moment (the server allows ~1 lookup per second for everyone).
    _debounce = Timer(const Duration(milliseconds: 900), () async {
      final label = await reverseGeocode(center.latitude, center.longitude);
      if (!mounted || _center != center) return;
      setState(() => _label = label);
    });
  }

  void _jumpTo(GeoPoint point) {
    final target = LatLng(point.latitude, point.longitude);
    _map.move(target, 16);
    setState(() {
      _center = target;
      _label = point.label;
    });
  }

  void _tell(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(text)));

  Future<void> _find() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final result = await lookupAddress(query);
    if (!mounted) return;
    setState(() => _busy = false);
    final found = result.point;
    if (found == null) {
      _tell(result.problem ?? 'Couldn’t find that address. Try adding the suburb or city.');
      return;
    }
    _jumpTo(found);
  }

  Future<void> _useMyLocation() async {
    setState(() => _busy = true);
    final (:point, :problem) = await findMyLocation();
    if (!mounted) return;
    setState(() => _busy = false);
    final here = point;
    if (here == null) {
      _tell(problem ?? 'Couldn’t get your location.');
      return;
    }
    _jumpTo(here);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial == null ? 12 : 16,
              onPositionChanged: (camera, hasGesture) => _moved(camera.center),
              onTap: (_, point) => _map.move(point, _map.camera.zoom),
            ),
            children: [
              const MapTileLayer(),
              const MapAttribution(alignment: AttributionAlignment.bottomLeft),
            ],
          ),
          // The pin stays in the middle; the map moves underneath it.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on, size: 48, color: _red),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _find(),
                decoration: InputDecoration(
                  hintText: 'Search an address or area',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _find),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 12)],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, color: _blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _label ?? 'Move the map to place the pin on your spot',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _useMyLocation,
                            icon: const Icon(Icons.my_location, size: 20),
                            label: const Text('My location'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(
                              context,
                              GeoPoint(_center.latitude, _center.longitude, label: _label),
                            ),
                            child: const Text('Confirm location'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
