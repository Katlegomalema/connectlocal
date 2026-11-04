import '../shared/app_config.dart';

/// Admin sign-in, kept apart from the customer/provider [AuthService] so the
/// phone app has no admin login at all.
///
/// BACKEND HAND-OVER (Supabase): replace [DevAdminAuth] with a class that signs
/// in with supabase.auth.signInWithPassword and then checks that the user's
/// row in `profiles` has role = 'admin' (RLS enforces this on every table too).
/// Then change the last line of this file.
abstract class AdminAuth {
  /// Returns normally for a valid admin. Throws [AdminAuthException] otherwise.
  Future<void> signIn({required String email, required String password});
}

class AdminAuthException implements Exception {
  final String message;
  const AdminAuthException(this.message);
  @override
  String toString() => message;
}

/// Local testing only. Credentials come from --dart-define, never from source:
///   --dart-define=DEV_ADMIN_EMAIL=you@example.com --dart-define=DEV_ADMIN_PASSWORD=...
/// With neither set, nobody can sign in until the backend is connected.
class DevAdminAuth implements AdminAuth {
  const DevAdminAuth();

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (AppConfig.devAdminEmail.isEmpty || AppConfig.devAdminPassword.isEmpty) {
      throw const AdminAuthException(
          'Admin sign-in needs the backend. For local testing run with DEV_ADMIN_EMAIL and DEV_ADMIN_PASSWORD.');
    }
    if (email.trim().toLowerCase() != AppConfig.devAdminEmail.toLowerCase() ||
        password != AppConfig.devAdminPassword) {
      throw const AdminAuthException('Wrong email or password.');
    }
  }
}

/// Set this to the real implementation when the backend is ready.
AdminAuth adminAuth = const DevAdminAuth();
