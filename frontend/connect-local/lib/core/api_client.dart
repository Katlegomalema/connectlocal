import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../features/shared/app_config.dart';

/// A failed API call, with a message that is safe and friendly to show to the user.
class ApiException implements Exception {
  /// HTTP status, or null when the server could not be reached.
  final int? statusCode;

  /// Machine-readable code from the backend (e.g. VALIDATION_ERROR, EMAIL_NOT_CONFIRMED), or NETWORK.
  final String code;

  /// Ready to show in a SnackBar.
  final String message;

  const ApiException(this.message, {this.statusCode, this.code = 'UNKNOWN'});

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => code == 'NETWORK';

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
/// - Refreshes the access token shortly before it expires, and once more after a 401, then retries.
/// - Turns error responses into [ApiException] with a friendly message.
class ApiClient {
  ApiClient({
    String baseUrl = AppConfig.apiBaseUrl,
    http.Client? httpClient,
    TokenStore? tokens,
    this.timeout = const Duration(seconds: 20),
  })  : _base = _normaliseBase(baseUrl),
        _http = httpClient ?? http.Client(),
        tokens = tokens ?? TokenStore();

  /// The app-wide client. Set up in main.dart.
  static late ApiClient instance;

  final String _base;
  final http.Client _http;
  final TokenStore tokens;
  final Duration timeout;
  Future<void>? _refreshing;

  /// Called when the session cannot be refreshed any more (the user must log in again).
  void Function()? onSessionExpired;

  bool get isConfigured => _base.isNotEmpty;
  String get baseUrl => _base;

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

  Future<Map<String, dynamic>> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

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
  }) async {
    if (!isConfigured) {
      throw const ApiException(
        'The app is not connected to a server. Build it with --dart-define=API_BASE_URL=...',
        code: 'NOT_CONFIGURED',
      );
    }
    if (auth && _expiresSoon && tokens.hasSession) await refreshSession();

    final response = await _rawRequest(method, path, body: body, bearer: auth ? tokens.accessToken : null);

    if (response.statusCode == 401 && auth && !isRetry && tokens.hasSession) {
      await refreshSession();
      return _send(method, path, body: body, auth: auth, isRetry: true);
    }
    return _decode(response);
  }

  bool get _expiresSoon {
    final expires = tokens.expiresAt;
    if (tokens.accessToken == null) return true;
    return expires != null && DateTime.now().isAfter(expires.subtract(const Duration(seconds: 60)));
  }

  Future<http.Response> _rawRequest(String method, String path, {Object? body, String? bearer}) async {
    final request = http.Request(method, Uri.parse('$_base$path'))
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (bearer != null && bearer.isNotEmpty) request.headers['Authorization'] = 'Bearer $bearer';
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException('The server took too long to answer. Please try again.', code: 'NETWORK');
    } catch (_) {
      // No internet, wrong address, CORS blocked (web), or a private Codespace port.
      throw const ApiException(
        "Can't reach ConnectLocal. Check your internet connection and try again.",
        code: 'NETWORK',
      );
    }
  }

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
    final response = await _rawRequest('POST', '/auth/refresh', body: {'refreshToken': refreshToken});
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
    Map<String, dynamic>? json;
    try {
      final parsed = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) json = parsed;
    } on FormatException {
      json = null;
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok && json != null) return json;
    if (ok || json == null) {
      // An HTML page instead of JSON: usually a sign-in page in front of a private Codespace port.
      throw ApiException(
        'The server sent an unexpected answer. If you use a Codespace, make port 3000 public.',
        statusCode: response.statusCode,
        code: 'BAD_RESPONSE',
      );
    }
    throw _friendlyError(response.statusCode, json);
  }

  static ApiException _friendlyError(int status, Map<String, dynamic> json) {
    final code = (json['code'] as String?) ?? 'HTTP_$status';
    final serverMessage = (json['message'] as String?)?.trim();
    String message;

    if (status == 429) {
      message = serverMessage != null && serverMessage.isNotEmpty && !serverMessage.startsWith('Too many requests')
          ? serverMessage
          : 'Too many attempts. Please wait a minute and try again.';
    } else if (status >= 500) {
      message = 'Something went wrong on our side. Please try again in a moment.';
    } else if (code == 'VALIDATION_ERROR') {
      // Show the first field problem ("Password must contain a number") rather than "Request validation failed".
      final errors = json['errors'];
      final first = errors is List && errors.isNotEmpty && errors.first is Map ? errors.first as Map : null;
      message = (first?['message'] as String?) ?? serverMessage ?? 'Please check your details and try again.';
    } else {
      message = serverMessage != null && serverMessage.isNotEmpty
          ? serverMessage
          : 'Something went wrong. Please try again.';
    }
    return ApiException(message, statusCode: status, code: code);
  }

  /// Convenience for callers: the `data` object of an answer.
  static Map<String, dynamic> dataOf(Map<String, dynamic> json) => _data(json);
}
