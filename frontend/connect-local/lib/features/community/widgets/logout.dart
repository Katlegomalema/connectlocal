import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../state/app_state.dart';

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
  await logoutAndGoToLogin(context);
}

/// Ends the session on the server and on this device, then shows the Login screen.
Future<void> logoutAndGoToLogin(BuildContext context) async {
  final navigator = Navigator.of(context);
  final app = AppScope.read(context);
  await authService.logout();
  // Forget the previous person's bookings, chats and notifications.
  app.signOut();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}
