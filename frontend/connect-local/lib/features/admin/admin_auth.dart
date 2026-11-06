import '../../core/api_client.dart';

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

/// The admin website signs in through the backend only (role must be 'admin').
AdminAuth createAdminAuth(ApiClient api) => ApiAdminAuth(api);

/// Set in main_admin.dart.
late AdminAuth adminAuth;
