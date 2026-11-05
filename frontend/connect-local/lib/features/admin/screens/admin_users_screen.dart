import 'package:flutter/material.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../../community/theme/app_theme.dart';
import '../../community/widgets/ui_kit.dart';

class _User {
  final String name;
  final String email;
  final String role; // Customer, Provider, Admin
  final String since;
  final int services;
  final int bookings;
  final UserAccount? account;

  bool get disabled => account?.disabled ?? false;

  _User(this.name, this.email, this.role, this.since,
      {this.services = 0, this.bookings = 0, this.account});
}

// Screen 34 - Admin Users
class AdminUsersScreen extends StatefulWidget {
  final String initialFilter;
  const AdminUsersScreen({super.key, this.initialFilter = 'ALL'});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _filters = ['ALL', 'Customers', 'Providers', 'Admins'];
  String _filter = 'ALL';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filter = ['ALL', 'Customers', 'Providers', 'Admins'].contains(widget.initialFilter)
        ? widget.initialFilter
        : 'ALL';
  }

  /// Accounts people created in the app. No sample or built-in rows.
  List<_User> _loadUsers(AppState app) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String since(DateTime d) => '${months[d.month - 1]} ${d.year}';
    return [
      for (final a in app.accounts)
        () {
          final business = app.providerOwnedBy(a.email);
          return _User(
            a.name,
            a.email,
            business == null ? 'Customer' : 'Provider',
            since(a.createdAt),
            services: business?.services.length ?? 0,
            bookings: business == null
                ? 0
                : app.allBookings.where((b) => b.providerId == business.id).length,
            account: a,
          );
        }(),
    ];
  }

  bool _matches(_User u) {
    final roleOk = _filter == 'ALL' || u.role == _filter.substring(0, _filter.length - 1);
    final q = _query.trim().toLowerCase();
    final queryOk =
        q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
    return roleOk && queryOk;
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(text)));
  }

  Widget _tile(_User u) {
    final isProvider = u.role == 'Provider';
    final roleColor = u.role == 'Admin'
        ? AppColors.navy
        : isProvider
            ? AppColors.teal
            : AppColors.muted;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: AppColors.avatarBg, shape: BoxShape.circle),
            child: const Icon(Icons.person_outline_rounded, color: AppColors.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(u.email, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(
                  isProvider
                      ? 'Since ${u.since} · ${u.services} services · ${u.bookings} bookings'
                      : 'Since ${u.since}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    StatusChip(u.role, color: roleColor),
                    if (u.disabled) const StatusChip('Disabled', color: AppColors.accent),
                  ],
                ),
              ],
            ),
          ),
          if (u.account != null)
            TextButton(
              onPressed: () {
                final app = AppScope.read(context);
                app.setAccountDisabled(u.account!, !u.account!.disabled);
                _message('${u.name} ${u.account!.disabled ? 'disabled' : 'enabled'}');
              },
              child: Text(u.disabled ? 'Enable' : 'Disable'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _loadUsers(AppScope.of(context)).where(_matches).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('All users')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search users',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            FilterTabs(
              labels: _filters,
              selected: _filters.indexOf(_filter),
              onChanged: (i) => setState(() => _filter = _filters[i]),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const EmptyState(icon: Icons.person_search_outlined, title: 'No users found')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _tile(shown[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
