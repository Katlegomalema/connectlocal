// End-to-end check of ApiAuthService against a REAL backend. Skipped unless E2E_EMAIL is given:
//   flutter test test/e2e --dart-define=API_BASE_URL=http://localhost:3000 \
//     --dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=...
// Use a confirmed test account; the test verifies a phone number on it.
import 'package:connect_local/core/api_client.dart';
import 'package:connect_local/features/auth/api_auth_service.dart';
import 'package:connect_local/features/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const email = String.fromEnvironment('E2E_EMAIL');
const password = String.fromEnvironment('E2E_PASSWORD');
const phone = String.fromEnvironment('E2E_PHONE', defaultValue: '+27820000001');

void main() {
  test('login -> phone code -> verify -> refresh -> logout against the real API', () async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient();
    final auth = ApiAuthService(api);

    await expectLater(auth.login(email: email, password: 'Wrong-pass-1!'), throwsA(isA<AuthException>()));

    final result = await auth.login(email: email, password: password);
    expect(result.email, email);
    expect(api.tokens.hasSession, isTrue);

    final sent = await auth.requestPhoneCode(phone);
    expect(sent.demoCode, matches(RegExp(r'^\d{6}$')));
    await expectLater(auth.verifyPhoneCode(phone, sent.demoCode == '000000' ? '111111' : '000000'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('tries left'))));
    await auth.verifyPhoneCode(phone, sent.demoCode!);

    final firstRefresh = api.tokens.refreshToken;
    await api.refreshSession();
    expect(api.tokens.refreshToken, isNot(firstRefresh));
    final me = ApiClient.dataOf(await api.get('/auth/me'))['user'] as Map;
    expect(me['phoneVerified'], isTrue);
    expect(me['phoneNumber'], phone);

    await auth.logout();
    expect(api.tokens.hasSession, isFalse);
  }, skip: email.isEmpty ? 'set E2E_EMAIL / E2E_PASSWORD to run against a real backend' : null);
}
