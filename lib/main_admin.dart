import 'package:flutter/material.dart';

import 'features/admin/screens/admin_login_screen.dart';
import 'features/auth/auth_service.dart';
import 'features/community/state/app_state.dart';
import 'features/community/theme/app_theme.dart';

/// ConnectLocal ADMIN website (separate from the phone app).
///
///   flutter run -d chrome -t lib/main_admin.dart
///   flutter build web -t lib/main_admin.dart
///
/// TODO (backend): this must talk to the same backend as the phone app. Until
/// then it runs on its own sample data, so applications sent from the phone
/// app won't show up here.
void main() => runApp(const ConnectLocalAdminApp());

class ConnectLocalAdminApp extends StatefulWidget {
  const ConnectLocalAdminApp({super.key});

  @override
  State<ConnectLocalAdminApp> createState() => _ConnectLocalAdminAppState();
}

class _ConnectLocalAdminAppState extends State<ConnectLocalAdminApp> {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    authService = LocalAuthService(_appState);
  }

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
