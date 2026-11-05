import '../../core/api_client.dart';
import '../shared/app_config.dart';

/// Admin sign-in, kept apart from the customer/provider [AuthService] so the
/// phone app has no admin login at all.
abstract class AdminAuth {
  /// Returns normally for a valid admin. Throws [AdminAuthException] otherwise.
  Future<void> signIn({required String email, required String password});

  /// Ends the admin session. Never throws.
  Future<void> signOut();
}

class AdminAuthException implements Exception {
  final String message;
  const AdminAuthException(this.message);
  @override
  String toString() => message;
}

/// Signs in through the ConnectLocal API and only lets in accounts whose role (from public.users on the
/// server) is 'admin'. Every admin API call is checked again by the backend.
class ApiAdminAuth implements AdminAuth {
  final ApiClient api;
  ApiAdminAuth(this.api);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final json = await api.post('/auth/login', auth: false, body: {
        'email': email.trim(),
        'password': password,
      });
      final data = ApiClient.dataOf(json);
      await api.tokens.saveFrom(data);
      final user = (data['user'] as Map?) ?? const {};
      if (user['role'] != 'admin') {
        await signOut();
        throw const AdminAuthException('This account is not an administrator.');
      }
    } on ApiException catch (e) {
      throw AdminAuthException(e.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (api.tokens.accessToken != null) await api.post('/auth/logout');
    } on ApiException {
      // Already signed out or offline: still forget the tokens.
    } finally {
      await api.tokens.clear();
    }
  }
}

/// DEV TOOLS ONLY (--dart-define=DEV_TOOLS=true): test the admin site without a backend.
/// Credentials come from --dart-define, never from source:
///   --dart-define=DEV_ADMIN_EMAIL=you@example.com --dart-define=DEV_ADMIN_PASSWORD=...
class DevAdminAuth implements AdminAuth {
  const DevAdminAuth();

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (AppConfig.devAdminEmail.isEmpty || AppConfig.devAdminPassword.isEmpty) {
      throw const AdminAuthException(
          'Admin sign-in needs the backend. For local testing run with DEV_ADMIN_EMAIL and DEV_ADMIN_PASSWORD.');
    }
    if (email.trim().toLowerCase() != AppConfig.devAdminEmail.toLowerCase() ||
        password != AppConfig.devAdminPassword) {
      throw const AdminAuthException('Wrong email or password.');
    }
  }

  @override
  Future<void> signOut() async {}
}

/// The backend by default; the offline stand-in only with DEV_TOOLS=true and no API_BASE_URL.
AdminAuth createAdminAuth(ApiClient api) =>
    AppConfig.devTools && !api.isConfigured ? const DevAdminAuth() : ApiAdminAuth(api);

/// Set in main_admin.dart.
late AdminAuth adminAuth;
