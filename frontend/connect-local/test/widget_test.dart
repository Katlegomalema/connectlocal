import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connect_local/features/community/state/app_state.dart';
import 'package:connect_local/core/api_client.dart';
import 'package:connect_local/features/auth/api_auth_service.dart';
import 'package:connect_local/features/auth/auth_service.dart';
import 'package:connect_local/main.dart';

void main() {
  testWidgets('Connect Local launches into the splash screen', (tester) async {
    final app = AppState();
    authService = ApiAuthService(ApiClient(baseUrl: '')); // not called in these tests
    await tester.pumpWidget(ConnectLocalApp(appState: app));
    expect(find.text('Local services, trusted connections'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
