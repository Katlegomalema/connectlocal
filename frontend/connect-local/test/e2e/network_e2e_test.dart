// Real-network checks of the API client (the app's own HTTP client) against a RUNNING backend.
// Skipped unless E2E_EMAIL is given:
//   flutter test test/e2e/network_e2e_test.dart --dart-define=API_BASE_URL=http://localhost:3000 \
//     --dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=... [--dart-define=E2E_WAIT_SECONDS=130]
//     [--dart-define=E2E_BROKEN_API=http://localhost:3006]  (a second server started with a broken database URL)
//     [--dart-define=E2E_CODESPACE_API=https://<codespace>-3000.app.github.dev]  (while that port is Private)
import 'package:connect_local/core/api_client.dart';
import 'package:connect_local/features/auth/api_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const email = String.fromEnvironment('E2E_EMAIL');
const password = String.fromEnvironment('E2E_PASSWORD');
const waitSeconds = int.fromEnvironment('E2E_WAIT_SECONDS', defaultValue: 130);
const brokenApi = String.fromEnvironment('E2E_BROKEN_API');
const codespaceApi = String.fromEnvironment('E2E_CODESPACE_API');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  if (email.isEmpty) {
    test('network e2e (skipped: pass E2E_EMAIL / E2E_PASSWORD to run against a real backend)', () {}, skip: true);
    return;
  }

  test('login still works after waiting $waitSeconds s "on the password field"', () async {
    final api = ApiClient();
    final auth = ApiAuthService(api);
    // The app opens: categories load (this opens a connection that then sits idle).
    await api.get('/search/categories', auth: false);
    final started = DateTime.now();
    await Future<void>.delayed(const Duration(seconds: waitSeconds));
    final result = await auth.login(email: email, password: password);
    expect(result.email, email);
    expect(api.tokens.hasSession, isTrue);
    // ignore: avoid_print
    print('login after ${DateTime.now().difference(started).inSeconds} s idle: OK');
  }, timeout: const Timeout(Duration(seconds: waitSeconds + 60)));

  test('an expired/invalid access token is refreshed once and the request retried', () async {
    final api = ApiClient();
    await ApiAuthService(api).login(email: email, password: password);
    final realRefresh = api.tokens.refreshToken;
    // Pretend the access token expired on the server but the app still thinks it is fine.
    await api.tokens.saveFrom({'accessToken': 'expired.${api.tokens.accessToken}', 'refreshToken': realRefresh, 'expiresIn': 3600});
    final json = await api.get('/notifications?limit=1');
    expect(json['success'], isTrue);
    expect(api.tokens.accessToken, isNot(startsWith('expired.')), reason: 'a new token was fetched');
  });

  test('a refused refresh token ends the session (user is sent to login)', () async {
    final api = ApiClient();
    var expired = false;
    api.onSessionExpired = () => expired = true;
    await api.tokens.saveFrom({'accessToken': 'expired.x', 'refreshToken': 'not-a-real-refresh-token', 'expiresIn': 3600});
    await expectLater(api.get('/notifications'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'SESSION_EXPIRED')));
    expect(expired, isTrue);
  });

  test('airplane mode (server unreachable): friendly message after 2 quick retries', () async {
    final api = ApiClient(baseUrl: 'http://127.0.0.1:9'); // nothing listens there
    final started = DateTime.now();
    await expectLater(
        api.get('/search/categories', auth: false),
        throwsA(isA<ApiException>()
            .having((e) => e.isNetwork, 'isNetwork', isTrue)
            .having((e) => e.message, 'message', contains('Check your internet connection'))));
    // ignore: avoid_print
    print('unreachable server: gave up after ${DateTime.now().difference(started).inMilliseconds} ms (3 tries)');
    await expectLater(api.post('/auth/login', auth: false, body: {'email': email, 'password': password}),
        throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue)));
  });

  test('a real 500 from the server shows "something went wrong on our side" (no details)', () async {
    if (brokenApi.isEmpty) return;
    final api = ApiClient(baseUrl: brokenApi);
    await expectLater(
        api.get('/search/categories', auth: false),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', greaterThanOrEqualTo(500))
            .having((e) => e.message, 'message', anyOf(contains('on our side'), contains('try again in a minute')))));
  });

  test('a Private Codespace port gives the "make port 3000 public" message, not a crash or logout', () async {
    if (codespaceApi.isEmpty) return;
    final api = ApiClient(baseUrl: codespaceApi);
    await expectLater(
        api.post('/auth/login', auth: false, body: {'email': email, 'password': password}),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'PRIVATE_PORT')
            .having((e) => e.message, 'message', contains('port 3000'))));
  });
}
