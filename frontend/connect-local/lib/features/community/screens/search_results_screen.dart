import 'package:flutter/material.dart';
import '../../shared/brand.dart';
import '../../shared/location_map.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';
import 'provider_profile_screen.dart';

/// Screen 12: Search Results (live-filters as you type)
class SearchResultsScreen extends StatefulWidget {
  final String query;
  final String category;
  final bool autofocus;
  const SearchResultsScreen({
    super.key,
    this.query = '',
    this.category = 'ALL',
    this.autofocus = false,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _ctrl;
  bool _nearestFirst = false;
  bool _showMap = false;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.query);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Map of the current results. Tap a pin to preview that provider.
  Widget _resultsMap(AppState app, List<ProviderModel> results) {
    final pins = <MapPin>[
      for (final p in results)
        if (p.latitude != null && p.longitude != null)
          MapPin(id: p.id, latitude: p.latitude!, longitude: p.longitude!, label: p.name),
    ];
    if (pins.isEmpty) {
      return const AppCard(
        child: Text('No locations to show for these results.',
            style: TextStyle(fontSize: 14, color: AppColors.muted)),
      );
    }
    final selected = results.where((p) => p.id == _selectedId).toList();
    return Column(
      children: [
        LocationMap(
          // A new key makes the map re-fit when the result set changes.
          key: ValueKey(pins.map((p) => p.id).join(',')),
          height: 300,
          pins: pins,
          selectedId: _selectedId,
          userLatitude: app.userLatitude,
          userLongitude: app.userLongitude,
          onPinTap: (pin) => setState(() => _selectedId = pin.id),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 12),
          ProviderCard(
            provider: selected.first,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProviderProfileScreen(providerId: selected.first.id)),
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Tap a pin to preview a provider.',
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final results = app.search(
      query: _ctrl.text,
      category: widget.category,
      nearestFirst: _nearestFirst,
    );
    final hasLocation = app.locationStatus == LocationStatus.ready;
    final count = results.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            AppSearchField(
              controller: _ctrl,
              autofocus: widget.autofocus,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _LocationBanner(app: app),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Top rated', style: TextStyle(fontSize: 13)),
                  selected: !_nearestFirst || !hasLocation,
                  onSelected: (_) => setState(() => _nearestFirst = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Nearest', style: TextStyle(fontSize: 13)),
                  selected: _nearestFirst && hasLocation,
                  // Needs a real GPS position to mean anything.
                  onSelected: hasLocation ? (_) => setState(() => _nearestFirst = true) : null,
                ),
                const Spacer(),
                ChoiceChip(
                  avatar: Icon(
                    _showMap ? Icons.view_list_rounded : Icons.map_outlined,
                    size: 18,
                    color: AppColors.teal,
                  ),
                  label: Text(_showMap ? 'List' : 'Map',
                      style: const TextStyle(fontSize: 13)),
                  selected: false,
                  onSelected: (_) => setState(() {
                    _showMap = !_showMap;
                    _selectedId = null;
                  }),
                ),
              ],
            ),
            if (_showMap) ...[
              const SizedBox(height: 12),
              _resultsMap(app, results),
            ],
            const SizedBox(height: 12),
            Center(
              child: Text(
                count == 1 ? '1 provider found' : '$count providers found',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_nearestFirst && hasLocation ? 'Nearest' : 'Top Rated',
                    style: headingStyle(size: 16, color: AppColors.text)),
                GestureDetector(
                  onTap: () => setState(_ctrl.clear),
                  child: const Text('See All',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.teal)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (results.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No providers found',
                  message: 'Try a different search or category.',
                ),
              ),
            for (final p in results) ...[
              ProviderCard(
                provider: p,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProviderProfileScreen(providerId: p.id)),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

/// Explains why distances aren't real yet, and how to fix it.
class _LocationBanner extends StatelessWidget {
  final AppState app;
  const _LocationBanner({required this.app});

  @override
  Widget build(BuildContext context) {
    final String? message;
    final bool needsSettings;
    switch (app.locationStatus) {
      case LocationStatus.serviceOff:
        message = 'Turn on your phone\'s location to see how far providers are.';
        needsSettings = true;
      case LocationStatus.denied:
        message = 'Allow location access to see how far providers are.';
        needsSettings = false;
      case LocationStatus.deniedForever:
        message = 'Location access is blocked. Enable it in Settings to see distances.';
        needsSettings = true;
      case LocationStatus.error:
        message = 'Couldn\'t get your location. Check your signal and try again.';
        needsSettings = false;
      case LocationStatus.loading:
        message = 'Finding your location…';
        needsSettings = false;
      case LocationStatus.unknown:
      case LocationStatus.ready:
        message = null;
        needsSettings = false;
    }
    if (message == null) return const SizedBox.shrink();
    final loading = app.locationStatus == LocationStatus.loading;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.avatarBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 16, color: AppColors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.text)),
          ),
          if (!loading) ...[
            if (needsSettings)
              TextButton(
                onPressed: app.openLocationHelp,
                child: const Text('Settings', style: TextStyle(fontSize: 13)),
              ),
            TextButton(
              onPressed: app.refreshLocation,
              child: const Text('Retry', style: TextStyle(fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}
