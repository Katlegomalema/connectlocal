import 'package:flutter/material.dart';
import '../../shared/brand.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/application_banner.dart';
import '../widgets/common_widgets.dart';
import 'customer_bookings_screen.dart';
import 'profile_screen.dart';
import 'provider_profile_screen.dart';
import 'search_results_screen.dart';

/// Screen 11: Home Feed
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  // Live: the list is replaced by the server's categories after loading.
  static List<String> get _categories => ['ALL', ...AppState.categories];
  String _category = 'ALL';

  @override
  void initState() {
    super.initState();
    // Ask for the customer's location once the home screen is on screen, so
    // provider distances are real GPS distances.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).refreshLocation();
    });
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  String get _filterCategory => _category;

  void _openProfile(ProviderModel p) =>
      _push(ProviderProfileScreen(providerId: p.id));

  static const _categoryIcons = <String, IconData>{
    'ALL': Icons.apps_rounded,
    'Home Repair': Icons.handyman_rounded,
    'Cleaning': Icons.cleaning_services_rounded,
    'Beauty': Icons.spa_rounded,
    'Tutoring': Icons.school_rounded,
    'Gardening': Icons.yard_rounded,
    'Security': Icons.shield_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final top = app.search(category: _filterCategory).take(2).toList();
    final firstName = app.customerName.trim().split(RegExp(r'\s+')).first;
    final nearYou = app.locationStatus == LocationStatus.ready;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                children: [
                  // Greeting + profile picture
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              firstName.isEmpty ? 'Hello' : 'Hello, $firstName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: headingStyle(size: 22),
                            ),
                            const SizedBox(height: 2),
                            const Text('What do you need help with today?',
                                style: TextStyle(fontSize: 13, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _push(const ProfileScreen()),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AvatarPlaceholder(
                              size: 46,
                              circle: true,
                              icon: Icons.person,
                              photo: app.customerPhoto,
                            ),
                            const SizedBox(height: 3),
                            const Text('Profile',
                                style: TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const ApplicationBanner(),

                  // Search
                  TextField(
                    onSubmitted: (q) => _push(SearchResultsScreen(query: q)),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                      hintText: 'Search services or providers',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.muted),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Categories
                  Text('Categories', style: headingStyle(size: 16, color: AppColors.text)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (_, i) => _CategoryTile(
                        label: _categories[i] == 'ALL' ? 'All' : _categories[i],
                        icon: _categoryIcons[_categories[i]] ?? Icons.category_rounded,
                        active: _categories[i] == _category,
                        onTap: () => setState(() => _category = _categories[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Top rated
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(_category == 'ALL' ? 'Top rated' : 'Top rated · $_category',
                              style: headingStyle(size: 16, color: AppColors.text)),
                          if (nearYou) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.location_on, size: 14, color: AppColors.teal),
                            const Text(' near you',
                                style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _push(SearchResultsScreen(category: _filterCategory)),
                        child: const Text('See all',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.teal)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (top.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded, size: 44, color: AppColors.muted),
                          SizedBox(height: 10),
                          Text('No providers in this category yet',
                              style: TextStyle(fontSize: 13, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  for (final p in top) ...[
                    _HomeFeedProviderCard(
                      provider: p,
                      onTap: () => _openProfile(p),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            AppBottomNav(
              items: const [
                NavItem(Icons.home_rounded, label: 'Home'),
                NavItem(Icons.description_outlined, label: 'Bookings'),
                NavItem(Icons.search_rounded, label: 'Search'),
                NavItem(Icons.person_rounded, label: 'Profile'),
              ],
              onTap: (i) {
                switch (i) {
                  case 1:
                    _push(const CustomerBookingsScreen());
                    break;
                  case 2:
                    _push(const SearchResultsScreen(autofocus: true));
                    break;
                  case 3:
                    _push(const ProfileScreen());
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: active ? AppColors.teal : AppColors.avatarBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon,
                    size: 26, color: active ? Colors.white : AppColors.teal),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.teal : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      );
}

class _HomeFeedProviderCard extends StatelessWidget {
  final ProviderModel provider;
  final VoidCallback onTap;
  const _HomeFeedProviderCard({
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final service = provider.activeServices.first;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AvatarPlaceholder(size: 72, photo: provider.displayPhoto, label: provider.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        provider.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: headingStyle(size: 14, weight: FontWeight.w600, color: AppColors.text),
                      ),
                      RatingRow(rating: provider.rating, reviews: provider.reviews),
                      Text(
                        service.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              service.hasPackages ? service.priceLabel : (service.isFixedPrice ? service.priceLabel : 'From ${money(service.price)}/hr'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.teal),
                            ),
                          ),
                          if (provider.distanceIsLive) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.location_on, size: 12, color: AppColors.muted),
                            Flexible(
                              child: Text(
                                distanceLabel(provider.distanceKm).replaceAll(' away', ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
