import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/payout_details_screen.dart';
import '../state/app_state.dart';
import 'action_feedback.dart';

/// A provider accepts a booking only after adding bank details, so there is
/// always somewhere to pay their earnings. Otherwise they are asked to add them.
/// Returns true if the booking was accepted.
Future<bool> confirmBooking(BuildContext context, AppState app, Booking booking) async {
  if (app.hasPayoutAccount) {
    return runAction(context, app.setStatus(booking, BookingStatus.confirmed), success: 'Booking accepted');
  }
  final add = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add your bank details first'),
      content: const Text(
          'ConnectLocal needs your bank account to pay you for this job. It takes a minute.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add bank details')),
      ],
    ),
  );
  if (add != true || !context.mounted) return false;
  final saved = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => const PayoutDetailsScreen()));
  if (saved == true && context.mounted) {
    return runAction(context, app.setStatus(booking, BookingStatus.confirmed), success: 'Booking accepted');
  }
  return false;
}
