import 'package:connect_local/features/auth/auth_service.dart';
import 'package:connect_local/features/auth/screens/register_screen.dart';
import 'package:connect_local/features/community/state/app_state.dart';
import 'package:connect_local/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<TextField>> openRegister(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final app = AppState();
  authService = LocalAuthService(app);
  await tester.pumpWidget(ConnectLocalApp(appState: app));
  await tester.pump(const Duration(seconds: 5)); // splash
  await tester.pumpAndSettle();
  tester.state<NavigatorState>(find.byType(Navigator).first)
      .push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  await tester.pumpAndSettle();
  return tester.widgetList<TextField>(find.byType(TextField)).toList();
}

Future<void> shortPasswordCase(WidgetTester tester, Size size) async {
  await openRegister(tester, size);
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Pat Doe');
  await tester.enterText(fields.at(1), 'pat@example.com');
  await tester.enterText(fields.at(2), 'short');
  await tester.enterText(fields.at(3), 'short');
  await tester.tap(find.text('SIGN UP'));
  await tester.pump();

  // The problem is shown under the password box, and the cursor is back in that box.
  expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  final password = tester.widget<TextField>(fields.at(2));
  expect(password.focusNode!.hasFocus, isTrue);
  expect(password.controller!.selection.textInside(password.controller!.text), 'short'); // selected, ready to retype

  // Typing straight away replaces it, and the error disappears.
  tester.testTextInput.enterText('Better1!pass');
  await tester.pump();
  expect(password.controller!.text, 'Better1!pass');
  expect(find.text('Password must be at least 8 characters'), findsNothing);
}

void main() {
  testWidgets('phone width: short password -> error under the box, cursor back in it, can retype',
      (t) => shortPasswordCase(t, const Size(400, 900)));
  testWidgets('desktop width: short password -> error under the box, cursor back in it, can retype',
      (t) => shortPasswordCase(t, const Size(1200, 900)));

  testWidgets('password rules match the backend', (tester) async {
    expect(RegisterScreenRules.problem('Short1!'), contains('8 characters'));
    expect(RegisterScreenRules.problem('longpass1!'), contains('capital'));
    expect(RegisterScreenRules.problem('LONGPASS1!'), contains('small'));
    expect(RegisterScreenRules.problem('Longpass!!'), contains('number'));
    expect(RegisterScreenRules.problem('Longpass11'), contains('symbol'));
    expect(RegisterScreenRules.problem('Longpass1!'), isNull);
  });

  testWidgets('mismatched confirmation is shown under the confirm box', (tester) async {
    await openRegister(tester, const Size(400, 900));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Pat Doe');
    await tester.enterText(fields.at(1), 'pat@example.com');
    await tester.enterText(fields.at(2), 'Longpass1!');
    await tester.enterText(fields.at(3), 'Longpass1?');
    await tester.tap(find.text('SIGN UP'));
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(tester.widget<TextField>(fields.at(3)).focusNode!.hasFocus, isTrue);
  });

  testWidgets('confirm box checks itself while typing', (tester) async {
    await openRegister(tester, const Size(400, 900));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), 'Longpass1!');
    await tester.enterText(fields.at(3), 'Long');            // still typing, matches so far
    await tester.pump();
    expect(find.text('Passwords do not match'), findsNothing);
    await tester.enterText(fields.at(3), 'Longpass1?');      // full length, different
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
    await tester.enterText(fields.at(3), 'Longpass1!');      // fixed
    await tester.pump();
    expect(find.text('Passwords do not match'), findsNothing);
    await tester.enterText(fields.at(2), 'Longpass2!');      // password changed afterwards
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
