import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/logout.dart';
import 'home_feed_screen.dart';
import 'provider_application_screens.dart';
import 'provider_dashboard_screen.dart';

/// Where someone lands after signing up with "I offer a service".
/// It walks them through: account -> business details & documents -> admin
/// review -> add services. It always shows the real status of their
/// application, so it is also where a rejected applicant applies again.
class ProviderOnboardingScreen extends StatelessWidget {
  const ProviderOnboardingScreen({super.key});

  void _browseAsCustomer(BuildContext context) => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeFeedScreen()),
        (route) => false,
      );

  void _openProviderMode(BuildContext context) => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ProviderDashboardScreen()),
        (route) => false,
      );

  /// Opens the form; when the person finishes it they come back to this page.
  void _apply(BuildContext context) => openBecomeProvider(
        context,
        onDone: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProviderOnboardingScreen()),
          (route) => false,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final application = app.myApplication;
    final status = application?.status;
    final approved = status == ApplicationStatus.approved;
    final hasServices = approved && app.activeProvider.services.isNotEmpty;

    // 0 = nothing sent, 1 = in review, 2 = approved, 3 = services added
    final step = application == null
        ? 0
        : status == ApplicationStatus.pending
            ? 1
            : approved
                ? (hasServices ? 3 : 2)
                : 0;

    final String title;
    final String text;
    switch (status) {
      case null:
        title = 'Set up your business';
        text = 'Your account is ready. Tell us about your business so we can verify it '
            'before customers can book you.';
      case ApplicationStatus.pending:
        title = 'Application under review';
        text = '${application!.businessName} is being checked by our team. '
            'You’ll see the result here and in your notifications.';
      case ApplicationStatus.approved:
        title = 'You’re approved!';
        text = 'Open Provider mode, then add your services and prices so customers can book you.';
      case ApplicationStatus.rejected:
        title = 'Application not approved';
        text = (application!.rejectionReason == null || application.rejectionReason!.isEmpty)
            ? 'Please check your details and documents, then apply again.'
            : 'Reason: ${application.rejectionReason}';
    }

    Widget stepRow(int index, String label, String hint) {
      final done = step > index;
      final current = step == index;
      final color = done
          ? AppColors.green
          : current
              ? AppColors.teal
              : AppColors.muted;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
                done
                    ? Icons.check_circle
                    : current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                color: color,
                size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: current ? FontWeight.w700 : FontWeight.w600,
                          color: done || current ? AppColors.navy : AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final Widget primary;
    if (approved) {
      primary = FilledButton(
        onPressed: () => _openProviderMode(context),
        child: const Text('Open Provider mode'),
      );
    } else if (status == ApplicationStatus.pending) {
      primary = FilledButton(
        onPressed: () => _browseAsCustomer(context),
        child: const Text('Browse as a customer meanwhile'),
      );
    } else {
      primary = FilledButton(
        onPressed: () => _apply(context),
        child: Text(status == null ? 'Start application' : 'Apply again'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Become a provider'),
        titleSpacing: 20,
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.text)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                children: [
                  stepRow(-1, 'Account created', 'Done – you can sign in anytime.'),
                  stepRow(0, 'Business details & documents',
                      'Registration number, ID, address and photos of your work.'),
                  stepRow(1, 'Admin review', 'We check your registration and ID (24–48 hours).'),
                  stepRow(2, 'Add your services & prices', 'Customers can book you once you add one.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            primary,
            if (status != ApplicationStatus.pending) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _browseAsCustomer(context),
                child: const Text('Browse as a customer for now'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
