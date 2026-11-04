import 'package:flutter/material.dart';

import '../../booking/screens/booking_screen.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class BookingSheet {
  static Future<void> show(
    BuildContext context,
    ProviderModel provider, {
    ServiceModel? service,
  }) async {
    final services = provider.activeServices;
    if (services.isEmpty) return;
    final chosen = service ?? services.first;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(provider.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Choose a service to continue', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            for (final item in services)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text('${item.priceLabel} · ${item.category}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openBooking(sheetContext, provider, item),
              ),
            if (!services.contains(chosen))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(chosen.name),
                subtitle: Text('${chosen.priceLabel} · ${chosen.category}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openBooking(sheetContext, provider, chosen),
              ),
          ],
        ),
      ),
    );
  }

  /// Goes straight to the booking form for [service] (no chooser).
  static void open(BuildContext context, ProviderModel provider, ServiceModel service) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          providerId: provider.id,
          providerName: provider.name,
          serviceId: service.id,
          serviceName: service.name,
          hourlyRate: service.price,
          packages: service.hasPackages ? service.packages : const [],
          fixedPrice: service.isFixedPrice,
        ),
      ),
    );
  }

  static void _openBooking(BuildContext context, ProviderModel provider, ServiceModel service) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          providerId: provider.id,
          providerName: provider.name,
          serviceId: service.id,
          serviceName: service.name,
          hourlyRate: service.price,
          packages: service.hasPackages ? service.packages : const [],
          fixedPrice: service.isFixedPrice,
        ),
      ),
    );
  }
}
