import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/provider_application_screens.dart';
import '../screens/provider_dashboard_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Tells a person who applied to become a provider where things stand:
/// under review, approved (and what to do next) or rejected (and why).
class ApplicationBanner extends StatelessWidget {
  const ApplicationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final a = app.myApplication;
    if (a == null) return const SizedBox.shrink();

    final IconData icon;
    final Color color;
    final String title;
    final String text;
    String? action;
    VoidCallback? onAction;

    switch (a.status) {
      case ApplicationStatus.pending:
        icon = Icons.hourglass_bottom_rounded;
        color = AppColors.orange;
        title = 'Application under review';
        text = 'The admin is checking ${a.businessName}. We\u2019ll notify you here as soon as it is decided.';
      case ApplicationStatus.approved:
        // Once the services are added there is nothing left to say.
        if (app.activeProvider.services.isNotEmpty) return const SizedBox.shrink();
        icon = Icons.verified_rounded;
        color = AppColors.green;
        title = 'You\u2019re approved!';
        text = 'Open Provider mode and add your services and prices. Customers can book you once you have added one.';
        action = 'Open Provider mode';
        onAction = () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const ProviderDashboardScreen()),
              (route) => false,
            );
      case ApplicationStatus.rejected:
        icon = Icons.info_outline_rounded;
        color = AppColors.accent;
        title = 'Application not approved';
        text = (a.rejectionReason == null || a.rejectionReason!.isEmpty)
            ? 'Please check your documents and apply again.'
            : 'Reason: ${a.rejectionReason}';
        action = 'Apply again';
        onAction = () => openBecomeProvider(context);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                    const SizedBox(height: 3),
                    Text(text,
                        style: const TextStyle(
                            fontSize: 14, height: 1.4, color: AppColors.text)),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: color),
                onPressed: onAction,
                child: Text(action),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
