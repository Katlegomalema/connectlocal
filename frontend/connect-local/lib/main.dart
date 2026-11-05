import 'dart:async';

import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/connect_local_repository.dart';
import 'features/auth/api_auth_service.dart';
import 'features/auth/auth_service.dart';
import 'features/shared/app_config.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/community/state/app_state.dart';
import 'features/community/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bring back everything saved on this device (applications, businesses,
  // bookings...) so a refresh or restart does not wipe the data.
  final appState = AppState();
  await appState.loadSaved();
  // Real accounts come from the backend. Device-only accounts (LocalAuthService) are a dev tool:
  // only with --dart-define=DEV_TOOLS=true and no API_BASE_URL.
  ApiClient.instance = ApiClient();
  await ApiClient.instance.tokens.load();
  authService = AppConfig.devTools && !ApiClient.instance.isConfigured
      ? LocalAuthService(appState)
      : ApiAuthService(ApiClient.instance);
  if (ApiClient.instance.isConfigured) {
    // Providers, services and categories come from the server (not from this device).
    appState.repository = ConnectLocalRepository(ApiClient.instance);
    unawaited(appState.loadFromServer());
  }
  runApp(ConnectLocalApp(appState: appState));
}

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
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: _constrainToPhoneWidth,
          home: const SplashScreen(),
        ),
      );

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
