import 'package:flutter/material.dart';

import '../../auth/screens/login_screen.dart';

/// Asks "Log out?" and, if confirmed, returns to the Login screen and clears
/// the navigation history. Used by Provider mode (Profile has its own button).
Future<void> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will need to sign in again.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  // TODO (backend): end the session before leaving.
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}
