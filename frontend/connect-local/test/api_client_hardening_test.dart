import 'dart:async';

import 'package:connect_local/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client_test.dart' show jsonResponse;

ApiClient client(MockClientHandler handler, {Duration timeout = const Duration(seconds: 20)}) => ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(handler),
      timeout: timeout,
      retryDelay: (_) => Duration.zero, // no waiting in tests
    );

Matcher apiError({String? code, int? status, Object? message}) => throwsA(isA<ApiException>()
    .having((e) => e.code, 'code', code ?? anything)
    .having((e) => e.statusCode, 'statusCode', status ?? anything)
    .having((e) => e.message, 'message', message ?? anything));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('retries', () {
    test('a GET is retried twice after network failures, then succeeds', () async {
      var calls = 0;
      final api = client((_) async {
        calls++;
        if (calls < 3) throw http.ClientException('Connection closed before full header was received');
        return jsonResponse(200, {'success': true, 'data': {'ok': true}});
      });
      final json = await api.get('/search/categories', auth: false);
      expect(ApiClient.dataOf(json)['ok'], isTrue);
      expect(calls, 3);
    });

    test('a GET gives up after 2 retries with the "check your connection" message', () async {
      var calls = 0;
      final api = client((_) async {
        calls++;
        throw http.ClientException('Failed host lookup'); // airplane mode
      });
      await expectLater(api.get('/x', auth: false), apiError(code: 'NETWORK', message: contains('internet connection')));
      expect(calls, 3);
    });

    test('a GET is retried on 503 but not on 500', () async {
      var calls = 0;
      final api503 = client((_) async {
        calls++;
        return calls == 1 ? jsonResponse(503, {'success': false}) : jsonResponse(200, {'success': true, 'data': {}});
      });
      await api503.get('/x', auth: false);
      expect(calls, 2);

      calls = 0;
      final api500 = client((_) async {
        calls++;
        return jsonResponse(500, {'success': false, 'code': 'INTERNAL_ERROR', 'message': 'TypeError: x is undefined'});
      });
      await expectLater(api500.get('/x', auth: false), apiError(status: 500, message: contains('on our side')));
      expect(calls, 1);
    });

    test('POST (payments, bookings) is NEVER retried automatically', () async {
      var calls = 0;
      final api = client((_) async {
        calls++;
        throw http.ClientException('Connection reset by peer');
      });
      await expectLater(api.post('/payments/intent', auth: false, body: {'bookingId': 'b1'}), apiError(code: 'NETWORK'));
      await expectLater(api.post('/bookings', auth: false, body: {}), apiError(code: 'NETWORK'));
      expect(calls, 2); // one try each
    });
  });

  test('a request that hangs ends with a friendly timeout message', () async {
    final api = client((_) => Completer<http.Response>().future, timeout: const Duration(milliseconds: 50));
    await expectLater(api.post('/auth/login', auth: false, body: {}), apiError(code: 'TIMEOUT', message: contains('Check your connection')));
  });

  group('private Codespace port', () {
    test('a 401 from the Codespace gate does not refresh, does not log out, and says what to do', () async {
      final paths = <String>[];
      var expired = false;
      final api = client((request) async {
        paths.add(request.url.path);
        return http.Response('', 401, headers: {'www-authenticate': 'tunnel'});
      })..onSessionExpired = () => expired = true;
      await api.tokens.saveFrom({'accessToken': 'A1', 'refreshToken': 'R1', 'expiresIn': 3600});

      await expectLater(api.get('/notifications'), apiError(code: 'PRIVATE_PORT', message: contains('port 3000')));
      expect(paths.where((p) => p.endsWith('/auth/refresh')), isEmpty);
      expect(expired, isFalse);
      expect(api.tokens.hasSession, isTrue, reason: 'still signed in');
    });

    test('a redirect to the GitHub sign-in page is reported, not followed', () async {
      final api = client((request) async {
        expect(request.followRedirects, isFalse);
        return http.Response('', 302, headers: {'location': 'https://github.dev/pf-signin?port=3000'});
      });
      await expectLater(api.post('/auth/login', auth: false, body: {}), apiError(code: 'PRIVATE_PORT'));
    });

    test('a refresh that hits the gate keeps the tokens (next request can try again)', () async {
      final api = client((request) async => request.url.path.endsWith('/auth/refresh')
          ? http.Response('', 401, headers: {'www-authenticate': 'tunnel'})
          : jsonResponse(401, {'success': false, 'code': 'AUTHENTICATION_ERROR', 'message': 'Invalid or expired token'}));
      await api.tokens.saveFrom({'accessToken': 'A1', 'refreshToken': 'R1', 'expiresIn': 3600});
      await expectLater(api.get('/notifications'), apiError(code: 'PRIVATE_PORT'));
      expect(api.tokens.refreshToken, 'R1');
    });
  });

  test('an expired access token is refreshed before the request (no 401 at all)', () async {
    final paths = <String>[];
    final api = client((request) async {
      paths.add('${request.method} ${request.url.path} ${request.headers['Authorization'] ?? '-'}');
      if (request.url.path.endsWith('/auth/refresh')) {
        return jsonResponse(200, {'success': true, 'data': {'accessToken': 'A2', 'refreshToken': 'R2', 'expiresIn': 3600}});
      }
      return jsonResponse(200, {'success': true, 'data': {}});
    });
    await api.tokens.saveFrom({'accessToken': 'A1', 'refreshToken': 'R1', 'expiresIn': -10}); // already expired
    await api.get('/notifications');
    expect(paths, ['POST /api/v1/auth/refresh -', 'GET /api/v1/notifications Bearer A2']);
  });

  group('error messages', () {
    Future<ApiException> errorFor(int status, Map<String, dynamic> body) async {
      final api = client((_) async => jsonResponse(status, body));
      try {
        await api.post('/x', auth: false, body: {});
      } on ApiException catch (e) {
        return e;
      }
      fail('no error');
    }

    test('400: every field problem is listed and kept per field', () async {
      final e = await errorFor(400, {
        'success': false,
        'code': 'VALIDATION_ERROR',
        'errors': [
          {'field': 'email', 'message': 'Enter a valid email address'},
          {'field': 'password', 'message': 'Password must contain a number'},
        ],
      });
      expect(e.fieldErrors, {'email': 'Enter a valid email address', 'password': 'Password must contain a number'});
      expect(e.message, 'Enter a valid email address\nPassword must contain a number');
    });

    test('400 bad JSON, 401, 403, 404, 409, 413, 429, 503', () async {
      expect((await errorFor(400, {'code': 'INVALID_JSON', 'message': 'The request body is not valid JSON'})).message,
          'The request body is not valid JSON');
      expect((await errorFor(401, {'code': 'AUTHENTICATION_ERROR', 'message': 'Invalid email or password'})).message,
          'Invalid email or password');
      expect((await errorFor(401, {'code': 'AUTHENTICATION_ERROR', 'message': 'Invalid or expired token'})).message,
          contains('log in again'));
      expect((await errorFor(403, {'code': 'AUTHORIZATION_ERROR', 'message': 'This action requires one of the following roles: provider'})).message,
          "Your account can't do this (it is only for provider accounts).");
      expect((await errorFor(403, {'code': 'AUTHORIZATION_ERROR', 'message': 'You do not own this booking'})).message,
          'You do not own this booking');
      expect((await errorFor(404, {'code': 'NOT_FOUND', 'message': 'Route GET /api/v1/x not found'})).message,
          contains("couldn't find"));
      expect((await errorFor(409, {'code': 'CONFLICT', 'message': 'That time slot is no longer available.'})).message,
          'That time slot is no longer available.');
      expect((await errorFor(413, {'code': 'PAYLOAD_TOO_LARGE'})).message, contains('too big'));
      expect((await errorFor(429, {'message': 'Too many requests, please try again later.'})).message, contains('wait a minute'));
      expect((await errorFor(503, {})).message, contains('try again in a minute'));
    });
  });
}
