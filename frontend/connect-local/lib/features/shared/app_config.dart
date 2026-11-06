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
}
