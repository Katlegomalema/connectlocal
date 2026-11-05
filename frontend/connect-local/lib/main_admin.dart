import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/connect_local_repository.dart';
import 'features/admin/admin_auth.dart';
import 'features/admin/screens/admin_login_screen.dart';
import 'features/community/state/app_state.dart';
import 'features/community/theme/app_theme.dart';
import 'features/shared/not_configured_screen.dart';

/// ConnectLocal ADMIN website (separate from the phone app).
///
///   flutter run -d chrome -t lib/main_admin.dart --dart-define=API_BASE_URL=https://...
///   flutter build web -t lib/main_admin.dart --dart-define=API_BASE_URL=https://...
///
/// Sign-in goes through the backend (role must be 'admin'); every screen shows server data.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.instance = ApiClient();
  if (!ApiClient.instance.isConfigured) {
    runApp(const NotConfiguredApp(target: 'lib/main_admin.dart'));
    return;
  }
  await ApiClient.instance.tokens.load();
  adminAuth = createAdminAuth(ApiClient.instance);
  runApp(const ConnectLocalAdminApp());
}

class ConnectLocalAdminApp extends StatefulWidget {
  const ConnectLocalAdminApp({super.key});

  @override
  State<ConnectLocalAdminApp> createState() => _ConnectLocalAdminAppState();
}

class _ConnectLocalAdminAppState extends State<ConnectLocalAdminApp> {
  final AppState _appState = AppState()..repository = ConnectLocalRepository(ApiClient.instance);

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
        state: _appState,
        child: MaterialApp(
          title: 'ConnectLocal Admin',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          // Desktop-width content, centred, instead of the 480px phone column.
          builder: (context, page) => ColoredBox(
            color: const Color(0xFFF3F4F6),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Material(color: Colors.white, child: page ?? const SizedBox.shrink()),
              ),
            ),
          ),
          home: const AdminLoginScreen(),
        ),
      );
}
