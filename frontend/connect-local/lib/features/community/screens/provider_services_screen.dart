import 'package:flutter/material.dart';

import '../../shared/brand.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';
import 'add_service_screen.dart';
import 'analytics_screen.dart';

/// Screen 26: Provider Services
class ProviderServicesScreen extends StatelessWidget {
  const ProviderServicesScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final services = app.activeProvider.services;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Services'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _push(context, const AddServiceScreen()),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Service',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: services.isEmpty
            ? Column(
                children: [
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.design_services_outlined,
                      title: 'No services yet',
                      message:
                          'Add what you offer and your price per hour. Customers can only book you once you have a service.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: PrimaryButton(
                      'Add your first service',
                      icon: Icons.add_rounded,
                      onPressed: () => _push(context, const AddServiceScreen()),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: services.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, i) => _ServiceTile(
                  service: services[i],
                  bookings: app.bookingsThisMonth(services[i]),
                  onEdit: () => _push(context, AddServiceScreen(service: services[i])),
                  onToggle: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final error = await app.toggleService(services[i]);
                    if (error != null) {
                      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(error)));
                    }
                  },
                  onAnalytics: () => _push(context, AnalyticsScreen(service: services[i])),
                ),
              ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final ServiceModel service;
  final int bookings;
  final VoidCallback onEdit, onToggle, onAnalytics;
  const _ServiceTile({
    required this.service,
    required this.bookings,
    required this.onEdit,
    required this.onToggle,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  service.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: headingStyle(
                      size: 16, weight: FontWeight.w600, color: AppColors.text),
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(
                service.active ? 'Active' : 'Inactive',
                color: service.active ? AppColors.green : AppColors.red,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                service.priceLabel,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.teal),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.star_rounded, size: 16, color: AppColors.orange),
              const SizedBox(width: 3),
              Text(
                service.rating == null ? 'New' : '${service.rating}',
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MetaRow(
            Icons.event_note_outlined,
            bookings == 1 ? '1 booking this month' : '$bookings bookings this month',
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              PillButton(label: 'Edit', outlined: true, onPressed: onEdit),
              const SizedBox(width: 10),
              PillButton(
                label: service.active ? 'Disable' : 'Enable',
                color: service.active ? AppColors.orange : AppColors.green,
                outlined: true,
                onPressed: onToggle,
              ),
              const Spacer(),
              TextButton(
                onPressed: onAnalytics,
                child: const Text('Analytics',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
