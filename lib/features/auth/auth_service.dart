import '../community/state/app_state.dart';

// ---------------------------------------------------------------------------
// BACKEND HAND-OVER POINT
//
// The Login screen calls [authService].login(...) and sends the person to the
// right place based on what comes back:
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

  /// True when the person has confirmed their email address (clicked the link
  /// in the sign-up email, or signed in with Google). TODO (backend): real value.
  final bool emailVerified;

  /// Set when the account IS one of the existing providers (demo accounts).
  final String? providerId;

  const AuthResult({
    required this.name,
    required this.email,
    this.isProvider = false,
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

/// Accounts created inside the app and kept on this device. Everyone (customers
/// and providers) registers themselves; there are no built-in accounts.
/// Admins never sign in through this app (see features/admin/admin_auth.dart).
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
    final error = app.registerAccount(name: name, email: email, password: password);
    if (error != null) throw AuthException(error);
  }

  @override
  Future<AuthResult> login({required String email, required String password}) async {
    final clean = email.trim();
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

  /// Google sign-in needs the backend (Supabase OAuth). The button is hidden
  /// unless built with --dart-define=GOOGLE_SIGNIN=true.
  @override
  Future<AuthResult> signInWithGoogle() async {
    throw const AuthException('Google sign-in is not connected yet.');
  }
}

/// Set once at start-up (see main.dart).
late AuthService authService;
