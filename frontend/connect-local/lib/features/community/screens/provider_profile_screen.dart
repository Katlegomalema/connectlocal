import 'package:flutter/material.dart';

import '../../shared/brand.dart';
import '../../shared/booking_maps.dart';
import '../../shared/photo_viewer.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/booking_sheet.dart';
import '../widgets/common_widgets.dart';
import '../widgets/reviews_section.dart';
import '../widgets/ui_kit.dart';

/// Screen 13: Provider Profile
class ProviderProfileScreen extends StatefulWidget {
  final String providerId;
  const ProviderProfileScreen({super.key, required this.providerId});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  String? _selectedServiceId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.providerById(widget.providerId);
    final services = p.activeServices;
    // The chosen service (the first one until the customer picks another).
    ServiceModel? selectedService;
    for (final s in services) {
      if (s.id == _selectedServiceId) selectedService = s;
    }
    if (selectedService == null && services.isNotEmpty) selectedService = services.first;
    final chosen = selectedService;
    final portfolio = p.portfolio;

    return Scaffold(
      appBar: AppBar(title: const Text('Provider Profile')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // ---- header ----
                  Center(
                    child: AvatarPlaceholder(
                      size: 96,
                      circle: true,
                      icon: Icons.person,
                      photo: p.avatar,
                      label: p.name,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      p.name,
                      textAlign: TextAlign.center,
                      style: headingStyle(size: 20, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(child: RatingRow(rating: p.rating, reviews: p.reviews)),
                  if (p.verified) ...[
                    const SizedBox(height: 8),
                    const Center(
                      child: StatusChip('Verified business', color: AppColors.teal),
                    ),
                  ],
                  // How customers can book this provider.
                  const SizedBox(height: 8),
                  Center(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        if (p.canBeVisited) const StatusChip('Visit the business', color: AppColors.green),
                        if (p.offersHouseCall || !p.canBeVisited)
                          const StatusChip('House calls', color: AppColors.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Only the real GPS distance is shown, never a sample number.
                  if (p.distanceIsLive)
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: AppColors.teal),
                          const SizedBox(width: 3),
                          Text(
                            distanceLabel(p.distanceKm),
                            style: const TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),

                  // ---- Business Location Map: where the business physically is ----
                  if (p.hasBusinessLocation) ...[
                    const SizedBox(height: 28),
                    BusinessLocationMap(
                      businessId: p.id,
                      businessName: p.name,
                      address: p.address,
                      latitude: p.latitude,
                      longitude: p.longitude,
                      height: 180,
                    ),
                  ],

                  // ---- portfolio ----
                  if (portfolio.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const SectionTitle('Portfolio'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 88,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: portfolio.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => showPhotoViewer(context, portfolio, initialIndex: i),
                          child: AvatarPlaceholder(size: 88, photo: portfolio[i]),
                        ),
                      ),
                    ),
                  ],

                  // ---- services ----
                  const SizedBox(height: 28),
                  const SectionTitle('Services'),
                  const SizedBox(height: 12),
                  if (services.isEmpty)
                    const AppCard(
                      child: Text(
                        'No services available right now.',
                        style: TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                    ),
                  for (final s in services) ...[
                    _ServiceOption(
                      service: s,
                      selected: s.id == chosen?.id,
                      onTap: () => setState(() => _selectedServiceId = s.id),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ---- reviews ----
                  const SizedBox(height: 18),
                  ReviewsSection(reviews: AppScope.of(context).reviewsFor(p.id)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: PrimaryButton(
                chosen == null ? 'Book Now' : 'Book ${chosen.name}',
                onPressed: chosen == null ? null : () => BookingSheet.open(context, p, chosen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// One service the customer can pick (tap to select, then use the Book button).
class _ServiceOption extends StatelessWidget {
  final ServiceModel service;
  final bool selected;
  final VoidCallback onTap;
  const _ServiceOption({required this.service, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.teal.withValues(alpha: 0.05) : Colors.white,
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.hairline,
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text(service.priceLabel,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.teal)),
                    if (service.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(service.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? AppColors.teal : AppColors.muted,
              ),
            ],
          ),
        ),
      );
}
