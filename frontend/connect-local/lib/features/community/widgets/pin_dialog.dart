import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// The provider has arrived: asks for the customer's 4-digit service PIN.
/// Entering it verifies the provider for this booking and starts the job.
Future<void> showStartJobPinDialog(
    BuildContext context, AppState app, Booking booking) async {
  final controller = TextEditingController();
  String? error;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final locked = booking.pinAttempts >= kMaxPinAttempts;
        return AlertDialog(
          title: const Text('Verify with the customer\u2019s PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'When you arrive, ask the customer for their 4-digit service PIN. '
                'Entering it confirms you are the provider for this booking and starts the job.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                enabled: !locked,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
                decoration: InputDecoration(counterText: '', hintText: '\u2022\u2022\u2022\u2022', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: locked
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(dialogContext);
                      // Checked on the server (5 tries) when connected.
                      final outcome = await app.startWithPin(booking, controller.text.trim());
                      switch (outcome.result) {
                        case PinResult.ok:
                          navigator.pop();
                          messenger.showSnackBar(const SnackBar(duration: Duration(seconds: 3),
                              content: Text('PIN verified. The job has started.')));
                        case PinResult.wrong:
                          setState(() => error = outcome.message ??
                              'Wrong PIN. ${kMaxPinAttempts - booking.pinAttempts} tries left.');
                        case PinResult.locked:
                          setState(() => error = outcome.message ??
                              'Too many wrong tries. Contact support to start this job.');
                        case PinResult.notAllowed:
                          setState(() => error = outcome.message ?? 'This job can\u2019t be started.');
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              child: const Text('Verify & Start'),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
}
