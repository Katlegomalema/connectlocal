import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/stat_card.dart';
import '../widgets/ui_kit.dart';

/// Analytics for all services, or for one service when [service] is given.
class AnalyticsScreen extends StatelessWidget {
  final ServiceModel? service;
  const AnalyticsScreen({super.key, this.service});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = service;
    final bookings = app.providerBookings
        .where((b) => s == null || b.serviceId == s.id)
        .toList();

    final counts = {
      for (final st in BookingStatus.values)
        st: bookings.where((b) => b.status == st).length
    };
    final total = bookings.length;

    final earned = s == null
        ? app.totalEarned
        : bookings
            .where((b) => b.status == BookingStatus.completed)
            .fold<int>(0, (sum, b) => sum + b.price);
    final thisMonth = s == null
        ? app.activeProvider.services.fold<int>(0, (sum, x) => sum + app.bookingsThisMonth(x))
        : app.bookingsThisMonth(s);
    final rating = s == null ? '${app.activeProvider.rating}' : (s.rating?.toString() ?? 'New');

    Color statusColor(BookingStatus st) {
      switch (st) {
        case BookingStatus.pending:
          return AppColors.orange;
        case BookingStatus.confirmed:
        case BookingStatus.completed:
          return AppColors.green;
        default:
          return AppColors.red;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s == null ? 'Analytics' : 'Analytics · ${s.name}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              Expanded(
                  child:
                      StatCard(label: 'Bookings this month', value: '$thisMonth')),
              const SizedBox(width: 16),
              Expanded(
                  child: StatCard(
                      icon: Icons.payments_outlined,
                      label: 'Earned',
                      value: money(earned))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: StatCard(
                      label: 'Pending', value: '${counts[BookingStatus.pending]}')),
              const SizedBox(width: 16),
              Expanded(
                  child: StatCard(
                      label: 'Average Rating', value: rating, showStar: true)),
            ]),
            const SizedBox(height: 24),
            const SectionTitle('Bookings by status'),
            const SizedBox(height: 10),
            for (final st in BookingStatus.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                        width: 96,
                        child: Text(st.label,
                            style: const TextStyle(fontSize: 14, color: AppColors.text))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : counts[st]! / total,
                          minHeight: 10,
                          backgroundColor: AppColors.inputBg,
                          color: statusColor(st),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${counts[st]}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            if (s == null) ...[
              const SizedBox(height: 24),
              const SectionTitle('By service'),
              const SizedBox(height: 6),
              for (final x in app.activeProvider.services)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(x.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      app.bookingsThisMonth(x) == 1
                          ? '1 booking this month'
                          : '${app.bookingsThisMonth(x)} bookings this month',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  trailing: const Icon(Icons.chevron_right, size: 22),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AnalyticsScreen(service: x)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
