/// Build-time settings. Nothing here is a secret that belongs in the source:
/// pass values with `--dart-define=NAME=value` (Android Studio: Run > Edit
/// Configurations > "Additional run args").
class AppConfig {
  AppConfig._();

  // ---- backend ------------------------------------------------------------
  /// The ConnectLocal API, e.g. `https://<codespace>-3000.app.github.dev` or `http://10.0.2.2:3000`
  /// (Android emulator -> your computer). "/api/v1" is added automatically.
  ///   --dart-define=API_BASE_URL=https://...
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  // ---- features that need a backend --------------------------------------
  /// Show "Continue with Google". Turn on once Google sign-in is configured.
  static const bool googleSignIn = bool.fromEnvironment('GOOGLE_SIGNIN');

  /// Phone verification: the app generates the 6-digit code and shows it on screen
  /// (no SMS is sent). ON by default for the semester project. When a real SMS
  /// service is connected, build with --dart-define=SIMULATED_SMS=false.
  static const bool simulatedSms = bool.fromEnvironment('SIMULATED_SMS', defaultValue: true);

  // ---- local development only (never ship a build with these on) ---------
  /// Stand-ins for services the backend will provide (email link, SMS code,
  /// password-reset link). OFF by default, so a normal build shows none of them.
  /// Run with `--dart-define=DEV_TOOLS=true` to test without a backend.
  static const bool devTools = bool.fromEnvironment('DEV_TOOLS');

  /// Admin login used only while testing the admin site without a backend.
  /// Supply BOTH with --dart-define (no credentials live in the source code).
  /// The real admin sign-in is a Supabase user with the `admin` role.
  static const String devAdminEmail = String.fromEnvironment('DEV_ADMIN_EMAIL');
  static const String devAdminPassword = String.fromEnvironment('DEV_ADMIN_PASSWORD');
}
