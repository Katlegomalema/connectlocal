import 'package:flutter/material.dart';

import '../../community/utils/category_icons.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../../community/theme/app_theme.dart';
import '../../community/widgets/ui_kit.dart';
import 'application_review_screen.dart';

/// Opens the full review page for one application.
void openApplicationReview(BuildContext context, ProviderApplicationRecord a) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ApplicationReviewScreen(applicationId: a.id)),
  );
}

/// One application in a list. Tapping it opens the review page; nothing can be
/// approved or rejected from the list itself.
class ApplicationTile extends StatelessWidget {
  final ProviderApplicationRecord application;
  const ApplicationTile(this.application, {super.key});

  @override
  Widget build(BuildContext context) {
    final a = application;
    final docs = a.registrationDoc != null && a.idDoc != null;
    final statusColor = a.status == ApplicationStatus.approved
        ? AppColors.green
        : a.status == ApplicationStatus.rejected
            ? AppColors.accent
            : AppColors.orange;
    return AppCard(
      onTap: () => openApplicationReview(context, a),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: AppColors.avatarBg, shape: BoxShape.circle),
            child: const Icon(Icons.storefront_outlined, color: AppColors.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(categoryIcon(a.services), size: 15, color: AppColors.teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('${a.services} · ${a.appliedLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusChip(a.status.label, color: statusColor),
                    StatusChip(docs ? 'Documents added' : 'Documents missing',
                        color: docs ? AppColors.green : AppColors.muted),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

// Screen 33 - Admin Provider Applications
class AdminProviderApplicationsScreen extends StatefulWidget {
  const AdminProviderApplicationsScreen({super.key});

  @override
  State<AdminProviderApplicationsScreen> createState() =>
      _AdminProviderApplicationsScreenState();
}

class _AdminProviderApplicationsScreenState extends State<AdminProviderApplicationsScreen> {
  int _tab = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    if (app.repository == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await app.loadApplications();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  static const _statuses = [
    ApplicationStatus.pending,
    ApplicationStatus.approved,
    ApplicationStatus.rejected,
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final shown = app.applicationsWithStatus(_statuses[_tab]);
    return Scaffold(
      appBar: AppBar(title: const Text('Provider applications')),
      body: SafeArea(
        child: Column(
          children: [
            FilterTabs(
              labels: [for (final s in _statuses) s.label],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: shown.isEmpty
                    ? ListView(children: const [
                        EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Nothing here',
                            message: 'Applications with this status will show up here.'),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => ApplicationTile(shown[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
