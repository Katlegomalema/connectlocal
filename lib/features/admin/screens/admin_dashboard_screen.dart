import 'package:flutter/material.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../../community/theme/app_theme.dart';
import '../../community/utils/format.dart';
import '../../community/widgets/stat_card.dart';
import '../../community/widgets/ui_kit.dart';
import 'admin_bookings_screen.dart';
import 'admin_earnings_screen.dart';
import 'admin_login_screen.dart';
import 'admin_payments_screen.dart';
import 'admin_payouts_screen.dart';
import 'admin_provider_applications_screen.dart';
import 'admin_users_screen.dart';

// Screen 32 - Admin Dashboard
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use the admin panel.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // TODO (backend): end the admin session before leaving.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pending = app.applicationsWithStatus(ApplicationStatus.pending);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text('Admin dashboard'),
        actions: [
          TextButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Log out',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                      label: 'Providers',
                      value: '${app.providers.length}',
                      icon: Icons.storefront_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                      label: 'Bookings',
                      value: '${app.allBookings.length}',
                      icon: Icons.event_available_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                      label: 'Pending reviews',
                      value: '${pending.length}',
                      icon: Icons.fact_check_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                      label: 'Deposits',
                      value: money(app.payments
                          .where((p) =>
                              p.kind == PaymentKind.bookingFee &&
                              p.status == PaymentStatus.paid)
                          .fold<int>(0, (t, p) => t + p.amount)),
                      icon: Icons.payments_outlined),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle('Manage'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _ActionTile(
                  icon: Icons.fact_check_outlined,
                  label: 'Applications',
                  badge: pending.length,
                  onTap: () => _open(context, const AdminProviderApplicationsScreen()),
                ),
                _ActionTile(
                  icon: Icons.people_outline,
                  label: 'Users',
                  onTap: () => _open(context, const AdminUsersScreen()),
                ),
                _ActionTile(
                  icon: Icons.event_note_outlined,
                  label: 'Bookings',
                  onTap: () => _open(context, const AdminBookingsScreen()),
                ),
                _ActionTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Payments',
                  onTap: () => _open(context, const AdminPaymentsScreen()),
                ),
                _ActionTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Payouts',
                  badge: app.payouts.where((p) => p.status == PayoutStatus.due).length,
                  onTap: () => _open(context, const AdminPayoutsScreen()),
                ),
                _ActionTile(
                  icon: Icons.savings_outlined,
                  label: 'Earnings',
                  onTap: () => _open(context, const AdminEarningsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SectionTitle(
              'Needs review (${pending.length})',
              trailing: TextButton(
                onPressed: () => _open(context, const AdminProviderApplicationsScreen()),
                child: const Text('View all'),
              ),
            ),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              const AppCard(
                child: Text('No applications are waiting for review.',
                    style: TextStyle(fontSize: 14, color: AppColors.muted)),
              ),
            for (final a in pending) ...[
              ApplicationTile(a),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.avatarBg,
        onDestinationSelected: (i) {
          if (i == 1) _open(context, const AdminProviderApplicationsScreen());
          if (i == 2) _open(context, const AdminUsersScreen());
          if (i == 3) _open(context, const AdminBookingsScreen());
          if (i == 4) _open(context, const AdminPaymentsScreen());
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Applications'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Payments'),
        ],
      ),
    );
  }
}


class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$badge',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
          ],
        ),
      );
}
