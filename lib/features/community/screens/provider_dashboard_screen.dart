import 'package:flutter/material.dart';

import '../../admin/screens/provider_business_profile_screen.dart';
import '../../shared/brand.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common_widgets.dart';
import '../widgets/logout.dart';
import '../widgets/payout_gate.dart';
import '../widgets/reviews_section.dart';
import '../widgets/stat_card.dart';
import '../widgets/ui_kit.dart';
import 'add_service_screen.dart';
import 'analytics_screen.dart';
import 'home_feed_screen.dart';
import 'messages_screen.dart';
import 'payout_details_screen.dart';
import 'payouts_screen.dart';
import 'provider_bookings_screen.dart';
import 'provider_services_screen.dart';

/// Screen 25: Provider Dashboard
class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  void _showNotifications(BuildContext context, AppState app) {
    final items = List<String>.from(app.notifications);
    app.markNotificationsRead();
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Notifications'),
            const SizedBox(height: 14),
            Flexible(
              child: items.isEmpty
                  ? const Text('Nothing new',
                      style: TextStyle(fontSize: 14, color: AppColors.muted))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 20),
                      itemBuilder: (_, i) => Text(items[i],
                          style: const TextStyle(fontSize: 14, color: AppColors.text)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final today = app.todayBookings;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Provider mode'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeFeedScreen()),
              (route) => false,
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: const Text('Customer',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _showNotifications(context, app),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (app.unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'profile') {
                _push(context, const ProviderBusinessProfileScreen());
              } else if (value == 'payouts') {
                _push(context, const PayoutsScreen());
              } else if (value == 'logout') {
                confirmLogout(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.storefront_outlined),
                  title: Text('Business profile'),
                ),
              ),
              PopupMenuItem(
                value: 'payouts',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.account_balance_outlined),
                  title: Text('Payouts & bank details'),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded, color: AppColors.red),
                  title: Text('Log out', style: TextStyle(color: AppColors.red)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (!app.hasPayoutAccount) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_outlined, color: AppColors.orange),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add your bank details so we can pay you. You need them before you can accept a booking.',
                        style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _push(context, const PayoutDetailsScreen()),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (app.activeProvider.activeServices.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rocket_launch_outlined, color: AppColors.teal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Get ready for your first booking',
                              style: headingStyle(size: 16, color: AppColors.text)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const _SetupStep(done: true, text: 'Business verified by the admin'),
                    const _SetupStep(
                        done: false, text: 'Add a service with your price per hour'),
                    const _SetupStep(
                        done: false, text: 'Customers can then find and book you'),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      'Add a service',
                      icon: Icons.add_rounded,
                      onPressed: () => _push(context, const AddServiceScreen()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.today_outlined,
                    label: "Today's Bookings",
                    value: '${today.length}',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: StatCard(
                    icon: Icons.hourglass_bottom_rounded,
                    label: 'Pending Bookings',
                    value: '${app.pendingCount}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.payments_outlined,
                    label: 'Total Earned',
                    value: money(app.totalEarned),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: StatCard(
                    label: 'Average Rating',
                    value: '${app.activeProvider.rating}',
                    showStar: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const SectionTitle("Today's Bookings"),
            const SizedBox(height: 12),
            if (today.isEmpty)
              const AppCard(
                padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Center(
                  child: Text('No bookings today',
                      style: TextStyle(fontSize: 14, color: AppColors.muted)),
                ),
              ),
            for (final b in today) ...[
              _BookingRow(booking: b),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            ReviewsSection(
              reviews: app.reviewsFor(app.activeProvider.id),
              emptyText: 'Reviews from your customers will appear here.',
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        items: const [
          NavItem(Icons.dashboard_rounded, label: 'Home'),
          NavItem(Icons.description_outlined, label: 'Bookings'),
          NavItem(Icons.bar_chart_rounded, label: 'Analytics'),
          NavItem(Icons.tune_rounded, label: 'Services'),
          NavItem(Icons.chat_bubble_outline_rounded, label: 'Messages'),
        ],
        onTap: (i) {
          switch (i) {
            case 1:
              _push(context, const ProviderBookingsScreen());
              break;
            case 2:
              _push(context, const AnalyticsScreen());
              break;
            case 3:
              _push(context, const ProviderServicesScreen());
              break;
            case 4:
              _push(context, const MessagesScreen());
              break;
          }
        },
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final Booking booking;
  const _BookingRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final b = booking;
    final pending = b.status == BookingStatus.pending;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.clientName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(b.serviceName,
                    style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    MetaRow(Icons.schedule_rounded, formatTime(b.dateTime)),
                    MetaRow(Icons.location_on_outlined,
                        '${b.distanceKm.toStringAsFixed(0)} km away'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          pending
              ? PillButton(
                  label: 'Confirm',
                  onPressed: () => confirmBooking(context, app, b),
                )
              : StatusChip(b.status.label, color: bookingStatusColor(b.status)),
        ],
      ),
    );
  }
}


class _SetupStep extends StatelessWidget {
  final bool done;
  final String text;
  const _SetupStep({required this.done, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                size: 20, color: done ? AppColors.green : AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.text)),
            ),
          ],
        ),
      );
}
