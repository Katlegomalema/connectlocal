import 'package:flutter/material.dart';

import '../admin/screens/admin_dashboard_screen.dart';
import '../community/screens/home_feed_screen.dart';
import '../shared/app_config.dart';
import '../community/screens/provider_dashboard_screen.dart';
import '../community/screens/provider_onboarding_screen.dart';
import '../community/state/app_state.dart';
import 'auth_service.dart';

/// Runs [action] (an email login or Google sign-in) and, on success, sends the
/// person to the right place: Home (providers also open on
/// their dashboard). Shows a message on failure; stays quiet if cancelled.
///
/// Returns true if the person got signed in.
Future<bool> runSignIn(
  BuildContext context,
  Future<AuthResult> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final app = AppScope.read(context);
  try {
    final result = await action();
    if (!context.mounted) return false;
    if (result.isAdmin && !kAdminInApp) {
      // Admins use the separate admin website, never the customer/provider app.
      messenger.showSnackBar(const SnackBar(duration: const Duration(seconds: 3), 
          content: Text('Admin accounts sign in on the ConnectLocal admin website.')));
      return false;
    }
    app.signIn(
      name: result.name,
      email: result.email,
      isProvider: result.isProvider,
      emailVerified: result.emailVerified,
      providerId: result.providerId,
    );
    // Someone who signed up as a provider continues with their application.
    final providerSignup = app.takeProviderSignupIntent();
    // Providers start in Provider mode and can switch to Customer mode from the
    // dashboard header or Profile. Each mode is its own stack, so Back never
    // drops a provider into the customer app by accident.
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => result.isAdmin
            ? const AdminDashboardScreen()
            : app.isProvider
                ? const ProviderDashboardScreen()
                : (providerSignup ? const ProviderOnboardingScreen() : const HomeFeedScreen()),
      ),
      (route) => false,
    );
    return true;
  } on AuthCancelledException {
    return false;
  } on AuthException catch (e) {
    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(duration: const Duration(seconds: 3), content: Text('Could not sign in. Please try again.')),
    );
  }
  return false;
}
