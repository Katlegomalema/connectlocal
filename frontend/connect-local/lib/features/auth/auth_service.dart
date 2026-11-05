import '../community/state/app_state.dart';
import '../shared/verification.dart';

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

  /// 'customer' or 'provider' (chosen at sign-up). A provider whose application is not approved yet has
  /// role 'provider' but [isProvider] false.
  final String role;

  /// The verified phone number (E.164, e.g. +27821234567), or null.
  final String? verifiedPhone;

  const AuthResult({
    required this.name,
    required this.email,
    this.isProvider = false,
    this.emailVerified = true,
    this.providerId,
    this.role = 'customer',
    this.verifiedPhone,
  });
}

/// Answer to "send me a phone code".
class PhoneCodeResult {
  /// Without a paid SMS service the backend returns the code so the app can show it like an SMS.
  /// Null when a real SMS was sent.
  final String? demoCode;
  final Duration validFor;

  const PhoneCodeResult({this.demoCode, this.validFor = const Duration(minutes: 5)});
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

  /// Creates a new account. [offersServices] is the sign-up choice: false = "I need a service"
  /// (customer), true = "I offer a service" (provider). Throw [AuthException] (readable message) if the
  /// email is taken or anything else is wrong.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    bool offersServices = false,
  });

  /// Ends the session (also on the server). Never throws.
  Future<void> logout();

  /// Sends a 6-digit code to [phoneE164] (e.g. +27821234567). The person must be signed in.
  Future<PhoneCodeResult> requestPhoneCode(String phoneE164);

  /// Checks the code. Throws [AuthException] with a readable message (wrong / expired / too many tries).
  Future<void> verifyPhoneCode(String phoneE164, String code);

  /// "Didn't receive the email?" Never says whether the account exists.
  Future<void> resendVerificationEmail(String email);

  /// "Continue with Google". Opens Google's account chooser, then returns the
  /// same [AuthResult] as [login]. Throw [AuthCancelledException] if the person
  /// backs out, or [AuthException] (with a readable message) for a real failure.
  ///
  /// BACKEND HAND-OVER (Supabase): call supabase.auth.signInWithOAuth /
  /// signInWithIdToken for Google here, then read the person's name, email and
  /// role from the signed-in user / profile row.
  Future<AuthResult> signInWithGoogle();
}

/// DEV TOOLS ONLY (--dart-define=DEV_TOOLS=true without API_BASE_URL): accounts created inside the app
/// and kept on this device. The real app uses ApiAuthService (features/auth/api_auth_service.dart).
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
    bool offersServices = false,
  }) async {
    final error = app.registerAccount(name: name, email: email, password: password);
    if (error != null) throw AuthException(error);
  }

  @override
  Future<void> logout() async {}

  /// No server: the code is generated and checked on this device.
  @override
  Future<PhoneCodeResult> requestPhoneCode(String phoneE164) async =>
      PhoneCodeResult(demoCode: OtpService.instance.send(phoneE164));

  @override
  Future<void> verifyPhoneCode(String phoneE164, String code) async {
    final result = OtpService.instance.check(phoneE164, code);
    switch (result) {
      case OtpCheck.ok:
        return;
      case OtpCheck.wrong:
        throw AuthException('Wrong code. ${OtpService.instance.triesLeft} tries left.');
      case OtpCheck.expired:
        throw const AuthException('That code has expired. Tap Resend for a new one.');
      case OtpCheck.tooManyTries:
        throw const AuthException('Too many wrong tries. Tap Resend for a new code.');
      case OtpCheck.noCode:
        throw const AuthException('Request a code first.');
    }
  }

  @override
  Future<void> resendVerificationEmail(String email) async {}

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
