import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../features/shared/app_config.dart';
import 'http_client_factory.dart';

/// A failed API call, with a message that is safe and friendly to show to the user.
class ApiException implements Exception {
  /// HTTP status, or null when the server could not be reached.
  final int? statusCode;

  /// Machine-readable code from the backend (e.g. VALIDATION_ERROR, EMAIL_NOT_CONFIRMED), or NETWORK,
  /// TIMEOUT, PRIVATE_PORT, BAD_RESPONSE, SESSION_EXPIRED.
  final String code;

  /// Ready to show in a SnackBar.
  final String message;

  /// 400 validation errors: field name -> what is wrong with it (empty for other errors).
  final Map<String, String> fieldErrors;

  const ApiException(this.message, {this.statusCode, this.code = 'UNKNOWN', this.fieldErrors = const {}});

  bool get isUnauthorized => statusCode == 401;

  /// The server could not be reached (no internet, timeout, server down): safe to try again later.
  bool get isNetwork => code == 'NETWORK' || code == 'TIMEOUT';

  @override
  String toString() => message;
}

/// Access + refresh token, kept with shared_preferences for now.
///
/// TODO (security): on Android/iOS move these to flutter_secure_storage; on the web this is localStorage,
/// which any script on the page can read.
class TokenStore {
  static const _accessKey = 'cl_access_token';
  static const _refreshKey = 'cl_refresh_token';
  static const _expiresKey = 'cl_access_expires_at'; // seconds since epoch

  String? accessToken;
  String? refreshToken;
  DateTime? expiresAt;

  bool get hasSession => refreshToken != null && refreshToken!.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_accessKey);
    refreshToken = prefs.getString(_refreshKey);
    final expires = prefs.getInt(_expiresKey);
    expiresAt = expires == null ? null : DateTime.fromMillisecondsSinceEpoch(expires * 1000);
  }

  /// Saves the tokens from a login/refresh response (`data` of the API answer).
  Future<void> saveFrom(Map<String, dynamic> data) async {
    accessToken = data['accessToken'] as String?;
    refreshToken = (data['refreshToken'] as String?) ?? refreshToken;
    final expiresAtSeconds = data['expiresAt'];
    final expiresIn = data['expiresIn'];
    if (expiresAtSeconds is num) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtSeconds.toInt() * 1000);
    } else if (expiresIn is num) {
      expiresAt = DateTime.now().add(Duration(seconds: expiresIn.toInt()));
    }
    final prefs = await SharedPreferences.getInstance();
    if (accessToken != null) await prefs.setString(_accessKey, accessToken!);
    if (refreshToken != null) await prefs.setString(_refreshKey, refreshToken!);
    if (expiresAt != null) await prefs.setInt(_expiresKey, expiresAt!.millisecondsSinceEpoch ~/ 1000);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_expiresKey);
  }
}

/// Talks to the ConnectLocal backend (`/api/v1/...`).
///
/// - Base URL from `--dart-define=API_BASE_URL=...` ("/api/v1" is added if missing).
/// - Sends `Authorization: Bearer <access token>` on authenticated calls.
/// - Refreshes the access token shortly before it expires; after a 401 from our API it refreshes once and
///   retries once. Only when the refresh itself is refused does the user have to log in again.
/// - Timeouts: connect 10 s (Android/iOS, see http_client_factory.dart), whole request 20 s.
/// - GET requests are retried up to 2 times (0.4 s, then 1.2 s later) when the network failed or the server
///   was briefly unavailable. POST/PUT/PATCH/DELETE (payments, bookings...) are NEVER retried automatically.
/// - Turns every error into an [ApiException] with a friendly message.
class ApiClient {
  ApiClient({
    String baseUrl = AppConfig.apiBaseUrl,
    http.Client? httpClient,
    TokenStore? tokens,
    this.timeout = const Duration(seconds: 20),
    Duration Function(int retry)? retryDelay,
  })  : _base = _normaliseBase(baseUrl),
        _http = httpClient ?? createHttpClient(),
        tokens = tokens ?? TokenStore(),
        _retryDelay = retryDelay ?? ((retry) => Duration(milliseconds: retry == 1 ? 400 : 1200));

  /// The app-wide client. Set up in main.dart.
  static late ApiClient instance;

  /// How many extra tries a GET gets.
  static const int maxGetRetries = 2;

  final String _base;
  final http.Client _http;
  final TokenStore tokens;
  final Duration timeout;
  final Duration Function(int retry) _retryDelay;
  Future<void>? _refreshing;

  /// Called when the session cannot be refreshed any more (the user must log in again).
  void Function()? onSessionExpired;

  bool get isConfigured => _base.isNotEmpty;
  String get baseUrl => _base;

  /// The API runs in a GitHub Codespace (its ports can be Private).
  bool get _isCodespace => _base.contains('.app.github.dev') || _base.contains('.github.dev');

  static String _normaliseBase(String value) {
    var base = value.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.isEmpty) return '';
    return base.endsWith('/api/v1') ? base : '$base/api/v1';
  }

  Future<Map<String, dynamic>> get(String path, {bool auth = true}) =>
      _send('GET', path, auth: auth);

  /// [headers]: extra request headers, e.g. `Idempotency-Key` (so a retried POST is not done twice).
  Future<Map<String, dynamic>> post(String path, {Object? body, bool auth = true, Map<String, String>? headers}) =>
      _send('POST', path, body: body, auth: auth, headers: headers);

  Future<Map<String, dynamic>> patch(String path, {Object? body, bool auth = true}) =>
      _send('PATCH', path, body: body, auth: auth);

  Future<Map<String, dynamic>> put(String path, {Object? body, bool auth = true}) =>
      _send('PUT', path, body: body, auth: auth);

  Future<Map<String, dynamic>> delete(String path, {bool auth = true}) =>
      _send('DELETE', path, auth: auth);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    required bool auth,
    bool isRetry = false,
    Map<String, String>? headers,
  }) async {
    if (!isConfigured) {
      throw const ApiException(
        'The app is not connected to a server. Build it with --dart-define=API_BASE_URL=...',
        code: 'NOT_CONFIGURED',
      );
    }
    if (auth && _expiresSoon && tokens.hasSession) await refreshSession();

    final response =
        await _requestWithRetries(method, path, body: body, bearer: auth ? tokens.accessToken : null, headers: headers);

    // Only OUR API's 401 (JSON) means "token expired". The Codespace sign-in gate also answers 401, but
    // refreshing would not help and must never log the person out.
    if (response.statusCode == 401 && auth && !isRetry && tokens.hasSession && !_isGate(response)) {
      await refreshSession();
      return _send(method, path, body: body, auth: auth, isRetry: true, headers: headers);
    }
    return _decode(response);
  }

  /// Sends the request; a GET is tried again (max [maxGetRetries] times) after a network failure, a timeout,
  /// or a 502/503/504. Anything else is sent exactly once.
  Future<http.Response> _requestWithRetries(String method, String path,
      {Object? body, String? bearer, Map<String, String>? headers}) async {
    final retries = method == 'GET' ? maxGetRetries : 0;
    for (var attempt = 0;; attempt++) {
      try {
        final response = await _rawRequest(method, path, body: body, bearer: bearer, headers: headers);
        final busy = response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504;
        if (!busy || attempt >= retries) return response;
      } on ApiException catch (e) {
        if (!e.isNetwork || attempt >= retries) rethrow;
      }
      await Future<void>.delayed(_retryDelay(attempt + 1));
    }
  }

  bool get _expiresSoon {
    final expires = tokens.expiresAt;
    if (tokens.accessToken == null) return true;
    return expires != null && DateTime.now().isAfter(expires.subtract(const Duration(seconds: 60)));
  }

  Future<http.Response> _rawRequest(String method, String path,
      {Object? body, String? bearer, Map<String, String>? headers}) async {
    final request = http.Request(method, Uri.parse('$_base$path'))
      ..headers.addAll(headers ?? const {})
      ..headers['Accept'] = 'application/json'
      // A redirect means "sign-in page" (private Codespace port), never a real answer of our API.
      ..followRedirects = false;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (bearer != null && bearer.isNotEmpty) request.headers['Authorization'] = 'Bearer $bearer';
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'The server is taking too long to answer. Check your connection and try again.',
        code: 'TIMEOUT',
      );
    } catch (_) {
      // No internet / airplane mode, wrong address, server stopped, or (in a browser) a CORS refusal, which is
      // what a Private Codespace port looks like from a web page.
      throw ApiException(
        _isCodespace
            ? "Can't reach ConnectLocal. Check your internet connection. If the server runs in a Codespace, "
                'make sure it is running and port 3000 is public (Ports tab → Port Visibility → Public).'
            : "Can't reach ConnectLocal. Check your internet connection and try again.",
        code: 'NETWORK',
      );
    }
  }

  /// The GitHub Codespaces sign-in gate in front of a Private port: a 302 to github.dev/pf-signin, or a 401
  /// with "WWW-Authenticate: tunnel", or an HTML page instead of JSON.
  static bool _isGate(http.Response response) {
    final location = response.headers['location'] ?? '';
    final authenticate = (response.headers['www-authenticate'] ?? '').toLowerCase();
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    if (response.statusCode >= 300 && response.statusCode < 400) return true;
    if (location.contains('pf-signin') || authenticate.contains('tunnel')) return true;
    if (response.statusCode == 401 && !contentType.contains('json') && response.body.trim().isEmpty) return true;
    return false;
  }

  static const ApiException _privatePort = ApiException(
    "The server didn't answer the app (it sent a sign-in page). If it runs in a Codespace, make port 3000 "
    'public: Ports tab → right-click 3000 → Port Visibility → Public.',
    code: 'PRIVATE_PORT',
  );

  /// Uploads file bytes to a signed Storage URL (from POST /uploads/sign). No API token is sent: the URL
  /// itself is the one-time permission.
  Future<void> putBytes(String url, List<int> bytes, String contentType) async {
    final http.Response response;
    try {
      response = await _http
          .put(Uri.parse(url), headers: {'Content-Type': contentType, 'x-upsert': 'false'}, body: bytes)
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const ApiException('The upload took too long. Check your connection and try again.', code: 'NETWORK');
    } catch (_) {
      throw const ApiException("Couldn't upload the file. Check your internet connection.", code: 'NETWORK');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final tooBig = response.statusCode == 413 || response.body.contains('maximum allowed size');
    throw ApiException(
      tooBig ? 'That file is too big. Please choose a smaller photo or PDF.' : "Couldn't upload the file. Please try again.",
      statusCode: response.statusCode,
      code: tooBig ? 'FILE_TOO_LARGE' : 'UPLOAD_FAILED',
    );
  }

  /// Gets a new access token with the refresh token. Concurrent callers share one request.
  Future<void> refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _doRefresh() async {
    final refreshToken = tokens.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) throw _sessionEnded();
    // A network problem or the Codespace gate is NOT a refused session: keep the tokens, let the call fail
    // with that message, and the next request tries again.
    final response = await _rawRequest('POST', '/auth/refresh', body: {'refreshToken': refreshToken});
    if (_isGate(response)) throw _privatePort;
    if (response.statusCode == 401 || response.statusCode == 403) {
      await tokens.clear();
      onSessionExpired?.call();
      throw _sessionEnded();
    }
    final json = _decode(response);
    await tokens.saveFrom(_data(json));
  }

  ApiException _sessionEnded() => const ApiException(
        'Your session has ended. Please log in again.',
        statusCode: 401,
        code: 'SESSION_EXPIRED',
      );

  /// `data` of a successful answer (`{ success: true, data: {...} }`).
  static Map<String, dynamic> _data(Map<String, dynamic> json) {
    final data = json['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (_isGate(response)) throw _privatePort;
    Map<String, dynamic>? json;
    try {
      final parsed = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) json = parsed;
    } on FormatException {
      json = null;
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok && json != null) return json;
    if (json == null) {
      // An HTML page instead of JSON: usually a sign-in page in front of a private Codespace port.
      throw ApiException(
        response.statusCode >= 500
            ? 'Something went wrong on our side. Please try again in a moment.'
            : 'The server sent an unexpected answer (a web page instead of data). If you use a Codespace, make '
                'port 3000 public (Ports tab → Port Visibility → Public).',
        statusCode: response.statusCode,
        code: 'BAD_RESPONSE',
      );
    }
    if (ok) return json;
    throw friendlyError(response.statusCode, json);
  }

  /// One clear message per kind of error. Server texts are only shown when they are meant for people
  /// (never for 5xx, which may contain internal details).
  static ApiException friendlyError(int status, Map<String, dynamic> json) {
    final code = (json['code'] as String?) ?? 'HTTP_$status';
    final serverMessage = (json['message'] as String?)?.trim() ?? '';
    String pick(String fallback) => serverMessage.isEmpty ? fallback : serverMessage;
    var fieldErrors = const <String, String>{};
    String message;

    if (status == 400 && (code == 'VALIDATION_ERROR' || json['errors'] is List)) {
      // "Password must contain a number" (each field), not "Request validation failed".
      final errors = json['errors'];
      fieldErrors = {
        if (errors is List)
          for (final e in errors)
            if (e is Map && e['message'] is String) '${e['field'] ?? ''}': e['message'] as String,
      };
      final messages = fieldErrors.values.toSet().toList();
      message = messages.isEmpty
          ? pick('Please check your details and try again.')
          : messages.take(3).join('\n');
    } else if (status == 400) {
      message = pick('Please check your details and try again.');
    } else if (status == 401) {
      // Login: "Invalid email or password". Elsewhere: the session is over.
      message = code == 'AUTHENTICATION_ERROR' && serverMessage.toLowerCase().contains('token')
          ? 'Your session has ended. Please log in again.'
          : pick('Please log in again.');
    } else if (status == 403) {
      message = serverMessage.startsWith('This action requires')
          ? "Your account can't do this (it is only for ${serverMessage.split(':').last.trim()} accounts)."
          : pick("You don't have permission to do that.");
    } else if (status == 404) {
      message = serverMessage.isEmpty || serverMessage.startsWith('Route ')
          ? "We couldn't find that. It may have been removed."
          : serverMessage;
    } else if (status == 409) {
      message = pick('That was changed in the meantime. Please refresh and try again.');
    } else if (status == 413) {
      message = 'That is too big to send. Please choose a smaller file.';
    } else if (status == 429) {
      message = serverMessage.isNotEmpty && !serverMessage.startsWith('Too many requests')
          ? serverMessage
          : 'Too many attempts. Please wait a minute and try again.';
    } else if (code == 'EXTERNAL_SERVICE_ERROR' && serverMessage.isNotEmpty) {
      // The server explains which outside service failed, e.g. "We could not send the confirmation email".
      message = serverMessage;
    } else if (status == 503) {
      message = 'ConnectLocal is busy or being updated. Please try again in a minute.';
    } else if (status >= 500) {
      message = 'Something went wrong on our side. Please try again in a moment.';
    } else {
      message = pick('Something went wrong. Please try again.');
    }
    return ApiException(message, statusCode: status, code: code, fieldErrors: fieldErrors);
  }

  /// Convenience for callers: the `data` object of an answer.
  static Map<String, dynamic> dataOf(Map<String, dynamic> json) => _data(json);
}
