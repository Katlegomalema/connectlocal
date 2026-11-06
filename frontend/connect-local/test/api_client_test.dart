import 'dart:convert';

import 'package:connect_local/core/api_client.dart';
import 'package:connect_local/features/auth/api_auth_service.dart';
import 'package:connect_local/features/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonResponse(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('base URL gets /api/v1 once, and Bearer token is sent', () async {
    late http.Request seen;
    final api = ApiClient(
      baseUrl: 'https://example.test/',
      httpClient: MockClient((request) async {
        seen = request;
        return jsonResponse(200, {'success': true, 'data': {}});
      }),
    );
    await api.tokens.saveFrom({'accessToken': 'A1', 'refreshToken': 'R1', 'expiresIn': 3600});
    await api.get('/auth/me');
    expect(seen.url.toString(), 'https://example.test/api/v1/auth/me');
    expect(seen.headers['Authorization'], 'Bearer A1');
  });

  test('a 401 refreshes the token once and retries the call', () async {
    final calls = <String>[];
    final api = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path} ${request.headers['Authorization'] ?? '-'}');
        if (request.url.path.endsWith('/auth/refresh')) {
          expect(jsonDecode(request.body), {'refreshToken': 'R1'});
          return jsonResponse(200, {
            'success': true,
            'data': {'accessToken': 'A2', 'refreshToken': 'R2', 'expiresIn': 3600}
          });
        }
        return request.headers['Authorization'] == 'Bearer A2'
            ? jsonResponse(200, {'success': true, 'data': {'ok': true}})
            : jsonResponse(401, {'success': false, 'code': 'AUTHENTICATION_ERROR', 'message': 'Invalid or expired token'});
      }),
    );
    await api.tokens.saveFrom({'accessToken': 'A1', 'refreshToken': 'R1', 'expiresIn': 3600});

    final json = await api.get('/auth/me');

    expect(ApiClient.dataOf(json)['ok'], true);
    expect(calls, ['GET /api/v1/auth/me Bearer A1', 'POST /api/v1/auth/refresh -', 'GET /api/v1/auth/me Bearer A2']);
    expect(api.tokens.refreshToken, 'R2'); // rotated refresh token is stored
  });

  test('a refused refresh ends the session with a friendly message', () async {
    var expired = false;
    final api = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async =>
          jsonResponse(401, {'success': false, 'code': 'AUTHENTICATION_ERROR', 'message': 'nope'})),
    )..onSessionExpired = () => expired = true;
    await api.tokens.saveFrom({'accessToken': 'A1', 'refreshToken': 'R1', 'expiresIn': 3600});

    await expectLater(api.get('/auth/me'), throwsA(isA<ApiException>()
        .having((e) => e.code, 'code', 'SESSION_EXPIRED')
        .having((e) => e.message, 'message', contains('log in again'))));
    expect(expired, isTrue);
    expect(api.tokens.hasSession, isFalse);
  });

  test('validation errors show the first field message', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async => jsonResponse(400, {
            'success': false,
            'code': 'VALIDATION_ERROR',
            'message': 'Request validation failed',
            'errors': [
              {'field': 'password', 'message': 'Password must contain a number'}
            ]
          })),
    );
    await expectLater(api.post('/auth/register', auth: false, body: {}),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Password must contain a number')));
  });

  test('server errors never show raw details', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async =>
          jsonResponse(500, {'success': false, 'code': 'INTERNAL_ERROR', 'message': 'relation "x" does not exist'})),
    );
    await expectLater(api.get('/x', auth: false),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('on our side'))));
  });

  test('an HTML page (private Codespace port) gives a helpful hint', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async => http.Response('<html>Sign in to GitHub</html>', 200)),
    );
    await expectLater(api.get('/x', auth: false),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('port 3000 public'))));
  });

  test('no network gives a friendly message', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async => throw http.ClientException('Failed host lookup')),
    );
    await expectLater(api.get('/x', auth: false),
        throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue)));
  });

  test('ApiAuthService: register sends the chosen role; login keeps tokens; admin is refused', () async {
    final bodies = <String, Map<String, dynamic>>{};
    var role = 'provider';
    final api = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        final path = request.url.path.replaceFirst('/api/v1', '');
        if (request.body.isNotEmpty) bodies[path] = jsonDecode(request.body) as Map<String, dynamic>;
        switch (path) {
          case '/auth/register':
            return jsonResponse(201, {'success': true, 'data': {'userId': 'u1'}});
          case '/auth/login':
            return jsonResponse(200, {
              'success': true,
              'data': {
                'accessToken': 'A1',
                'refreshToken': 'R1',
                'expiresIn': 3600,
                'user': {
                  'fullName': 'Pat Doe',
                  'email': 'pat@example.test',
                  'role': role,
                  'emailVerified': true,
                  'phoneVerified': true,
                  'phoneNumber': '+27821234567'
                }
              }
            });
          case '/providers/me':
            return jsonResponse(404, {'success': false, 'code': 'NOT_FOUND', 'message': 'Provider profile not found'});
          default:
            return jsonResponse(200, {'success': true, 'data': {'loggedOut': true}});
        }
      }),
    );
    final auth = ApiAuthService(api);

    await auth.register(name: 'Pat Doe', email: 'pat@example.test', password: 'Secret1!x', offersServices: true);
    expect(bodies['/auth/register']!['role'], 'provider');

    final result = await auth.login(email: 'pat@example.test', password: 'Secret1!x');
    expect(result.role, 'provider');
    expect(result.isProvider, isFalse); // no approved business yet -> provider application
    expect(result.verifiedPhone, '+27821234567');
    expect(api.tokens.accessToken, 'A1');

    role = 'admin';
    await expectLater(auth.login(email: 'a@example.test', password: 'x'), throwsA(isA<AuthException>()));
    expect(api.tokens.hasSession, isFalse); // admin session closed again in the phone app
  });
}
