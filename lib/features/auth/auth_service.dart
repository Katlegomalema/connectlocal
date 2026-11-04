import 'package:flutter/foundation.dart' show kDebugMode;

import '../community/state/app_state.dart';

// ---------------------------------------------------------------------------
// BACKEND HAND-OVER POINT
//
// The Login screen calls [authService].login(...) and sends the person to the
// right place based on what comes back:
//   isAdmin    -> Admin dashboard
//   isProvider -> normal Home, and "Switch to Provider mode" appears on Profile
//   otherwise  -> normal customer Home
//
// To connect the real backend: write a class that implements [AuthService]
// (call your login endpoint, read the role from the response) and change the
// last line of this file to use it. Nothing else in the app needs to change.
// ---------------------------------------------------------------------------

/// What the backend tells the app about the person who just signed in.
class AuthResult {
  final String name;
  final String email;

  /// An approved provider: can switch to Provider mode.
  final bool isProvider;

  /// An admin: goes straight to the Admin dashboard.
  final bool isAdmin;

  /// True when the person has confirmed their email address (clicked the link
  /// in the sign-up email, or signed in with Google). TODO (backend): real value.
  final bool emailVerified;

  /// Set when the account IS one of the existing providers (demo accounts).
  final String? providerId;

  const AuthResult({
    required this.name,
    required this.email,
    this.isProvider = false,
    this.isAdmin = false,
    this.emailVerified = true,
    this.providerId,
  });
}

/// Throw this from [AuthService.login] for a wrong password, no network, etc.
/// The message is shown to the user.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Throw this from [AuthService.signInWithGoogle] when the person closes the
/// Google window or taps "Cancel". The app stays quiet (no error message).
class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

abstract class AuthService {
  Future<AuthResult> login({required String email, required String password});

  /// Creates a new account. Throw [AuthException] (readable message) if the
  /// email is taken or anything else is wrong.
  Future<void> register({required String name, required String email, required String password});

  /// "Continue with Google". Opens Google's account chooser, then returns the
  /// same [AuthResult] as [login]. Throw [AuthCancelledException] if the person
  /// backs out, or [AuthException] (with a readable message) for a real failure.
  ///
  /// BACKEND HAND-OVER (Supabase): call supabase.auth.signInWithOAuth /
  /// signInWithIdToken for Google here, then read the person's name, email and
  /// role from the signed-in user / profile row.
  Future<AuthResult> signInWithGoogle();
}

/// Build with `--dart-define=DEMO_ACCOUNTS=true` to allow the built-in admin
/// login in a release build. Off by default.
const bool _adminInRelease = bool.fromEnvironment('DEMO_ACCOUNTS');

/// The built-in admin login (admins are never self-registered).
/// TODO (backend): replace with a real admin role in the database.
const kAdminEmail = 'admin@email.com';
const kAdminPassword = 'Test@1234';

/// Accounts created inside the app and kept on this device. Everyone (customers
/// and providers) registers themselves; the only built-in account is the admin.
/// TODO (backend): replace with Supabase Auth (see FRONTEND_HANDOVER.md).
class LocalAuthService implements AuthService {
  final AppState app;
  const LocalAuthService(this.app);

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (email.trim().toLowerCase() == kAdminEmail) {
      throw const AuthException('That email can\u2019t be used. Please choose another.');
    }
    final error = app.registerAccount(name: name, email: email, password: password);
    if (error != null) throw AuthException(error);
  }

  @override
  Future<AuthResult> login({required String email, required String password}) async {
    final clean = email.trim();
    if (clean.toLowerCase() == kAdminEmail) {
      if ((kDebugMode || _adminInRelease) && password == kAdminPassword) {
        return AuthResult(name: 'Admin User', email: clean, isAdmin: true);
      }
      throw const AuthException('Wrong email or password.');
    }
    try {
      final account = app.authenticate(clean, password);
      return AuthResult(
        name: account.name,
        email: account.email,
        emailVerified: account.emailVerified,
      );
    } on StateError catch (e) {
      throw AuthException(e.message);
    }
  }

  /// Stand-in until the backend is connected: pretends Google signed the
  /// person in (and creates a Google account the first time).
  @override
  Future<AuthResult> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    const email = 'google.user@gmail.com';
    if (app.accountByEmail(email) == null) {
      app.registerAccount(name: 'Google User', email: email, password: 'google-${DateTime.now().microsecondsSinceEpoch}');
      app.verifyEmailFor(email);
    }
    final account = app.accountByEmail(email)!;
    return AuthResult(name: account.name, email: account.email, emailVerified: true);
  }
}

/// Set once at start-up (see main.dart).
late AuthService authService;
