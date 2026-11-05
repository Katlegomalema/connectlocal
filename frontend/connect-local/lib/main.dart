import 'dart:async';

import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/connect_local_repository.dart';
import 'features/auth/api_auth_service.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/screens/account_recovery_screens.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/community/state/app_state.dart';
import 'features/community/theme/app_theme.dart';
import 'features/shared/not_configured_screen.dart';

/// The customer + provider app. Everything comes from the ConnectLocal API:
///   `flutter run --dart-define=API_BASE_URL=https://<codespace>-3000.app.github.dev`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.instance = ApiClient();
  if (!ApiClient.instance.isConfigured) {
    runApp(const NotConfiguredApp(target: 'lib/main.dart'));
    return;
  }
  await ApiClient.instance.tokens.load();
  authService = ApiAuthService(ApiClient.instance);
  final appState = AppState()..repository = ConnectLocalRepository(ApiClient.instance);
  // The refresh token was refused (signed out elsewhere, account suspended, too old): back to Login.
  ApiClient.instance.onSessionExpired = () {
    appState.signOut();
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    appMessengerKey.currentState?.showSnackBar(const SnackBar(
        duration: Duration(seconds: 4), content: Text('Your session has ended. Please log in again.')));
  };
  // Categories and providers for the first screens (the rest loads after sign-in).
  unawaited(appState.loadFromServer());
  runApp(ConnectLocalApp(appState: appState));
}

/// Lets code outside the widget tree (the API client) open Login and show a message.
final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class ConnectLocalApp extends StatefulWidget {
  final AppState appState;
  const ConnectLocalApp({super.key, required this.appState});

  @override
  State<ConnectLocalApp> createState() => _ConnectLocalAppState();
}

class _ConnectLocalAppState extends State<ConnectLocalApp> {
  late final AppState _appState = widget.appState;

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
        state: _appState,
        child: MaterialApp(
          title: 'Connect Local',
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appMessengerKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: _constrainToPhoneWidth,
          // A password-reset link (web) opens the "new password" page; otherwise the normal start.
          home: _recoveryToken() == null ? const SplashScreen() : CreateNewPasswordScreen(token: _recoveryToken()),
        ),
      );

  /// `?type=recovery&token_hash=...` from the reset email (see SETUP.md), or null.
  static String? _recoveryToken() {
    final query = Uri.base.queryParameters;
    final token = query['token_hash'];
    return query['type'] == 'recovery' && token != null && token.isNotEmpty ? token : null;
  }

  /// The whole app is designed for a phone-sized layout. On wide screens
  /// (browser / desktop) we keep it at phone width and centre it, instead of
  /// stretching every screen across the full window.
  static const double _maxAppWidth = 480;

  static Widget _constrainToPhoneWidth(BuildContext context, Widget? page) {
    final media = MediaQuery.of(context);
    if (page == null) return const SizedBox.shrink();
    // Tapping outside a text field closes the keyboard.
    final child = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: page,
    );
    if (media.size.width <= _maxAppWidth) return child;
    return ColoredBox(
      color: const Color(0xFFE9ECEF),
      child: Center(
        child: Container(
          width: _maxAppWidth,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          // Report the narrower width so anything using MediaQuery.size
          // (e.g. chat bubble max widths) sizes itself to the phone column.
          child: MediaQuery(
            data: media.copyWith(size: Size(_maxAppWidth, media.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
