import 'package:flutter/material.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../../community/theme/app_theme.dart';
import '../../community/widgets/ui_kit.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AppScope.read(context).adminUsers.isEmpty) AppScope.read(context).loadAdminData();
    });
    _filter = ['ALL', 'Customers', 'Providers', 'Admins'].contains(widget.initialFilter)
        ? widget.initialFilter
        : 'ALL';
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _since(DateTime d) => '${_months[d.month - 1]} ${d.year}';
  static String _roleLabel(String role) => switch (role) {
        'provider' => 'Provider',
        'admin' => 'Admin',
        _ => 'Customer',
      };

  final Set<String> _busy = {};


  bool _matches(AdminUser u) {
    final roleOk = _filter == 'ALL' || _roleLabel(u.role) == _filter.substring(0, _filter.length - 1);
    final q = _query.trim().toLowerCase();
    final queryOk =
        q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
    return roleOk && queryOk;
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(text)));
  }

  Future<void> _toggle(AdminUser u) async {
    setState(() => _busy.add(u.id));
    final error = await AppScope.read(context).setUserActive(u, !u.isActive);
    if (!mounted) return;
    setState(() => _busy.remove(u.id));
    _message(error ?? '${u.name} ${u.isActive ? 'can sign in again' : 'is suspended (cannot sign in)'}');
  }

  Widget _tile(AdminUser u) {
    final role = _roleLabel(u.role);
    final isProvider = u.role == 'provider';
    final roleColor = u.role == 'admin'
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
                  isProvider && u.businessName != null
                      ? 'Since ${_since(u.createdAt)} · ${u.businessName} (${u.businessStatus ?? 'draft'})'
                      : 'Since ${_since(u.createdAt)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    StatusChip(role, color: roleColor),
                    if (!u.isActive)
                      StatusChip(u.status == 'deactivated' ? 'Deactivated' : 'Suspended', color: AppColors.accent),
                  ],
                ),
              ],
            ),
          ),
          // Admins cannot be suspended here (the server also refuses suspending yourself).
          if (u.role != 'admin' && u.status != 'deactivated')
            TextButton(
              onPressed: _busy.contains(u.id) ? null : () => _toggle(u),
              child: Text(u.isActive ? 'Suspend' : 'Re-activate'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final shown = app.adminUsers.where(_matches).toList();
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
              child: RefreshIndicator(
                onRefresh: () => app.loadAdminData(),
                child: shown.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 60),
                      EmptyState(icon: Icons.person_search_outlined, title: 'No users found'),
                    ])
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _tile(shown[i]),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
