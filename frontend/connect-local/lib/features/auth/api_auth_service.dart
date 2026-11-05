import '../../core/api_client.dart';
import 'auth_service.dart';

/// [AuthService] backed by the ConnectLocal API (`/api/v1/auth/...`).
///
/// The backend talks to Supabase Auth; the app never sees Supabase keys.
class ApiAuthService implements AuthService {
  final ApiClient api;
  ApiAuthService(this.api);

  /// Runs an API call and turns [ApiException] into the [AuthException] the screens already show.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    bool offersServices = false,
  }) =>
      _guard(() async {
        await api.post('/auth/register', auth: false, body: {
          'email': email.trim(),
          'password': password,
          'fullName': name.trim(),
          'role': offersServices ? 'provider' : 'customer',
        });
      });

  @override
  Future<AuthResult> login({required String email, required String password}) => _guard(() async {
        final json = await api.post('/auth/login', auth: false, body: {
          'email': email.trim(),
          'password': password,
        });
        final data = ApiClient.dataOf(json);
        await api.tokens.saveFrom(data);
        final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? const {};
        final role = (user['role'] as String?) ?? 'customer';

        if (role == 'admin') {
          // Admins use the separate admin website, never the phone app.
          await logout();
          throw const AuthException('Admin accounts sign in on the admin website.');
        }

        return AuthResult(
          userId: (user['id'] as String?) ?? '',
          name: (user['fullName'] as String?) ?? '',
          email: (user['email'] as String?) ?? email.trim(),
          role: role,
          emailVerified: user['emailVerified'] == true,
          verifiedPhone: user['phoneVerified'] == true ? user['phoneNumber'] as String? : null,
          isProvider: role == 'provider' && await _providerIsApproved(),
        );
      });

  /// A provider gets Provider mode once the admin approved their business.
  Future<bool> _providerIsApproved() async {
    try {
      final json = await api.get('/providers/me');
      final provider = (ApiClient.dataOf(json)['provider'] as Map?) ?? const {};
      return provider['verification_status'] == 'verified';
    } on ApiException catch (e) {
      if (e.statusCode == 404) return false; // no business profile yet: continue with the application
      rethrow;
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    // Hidden unless built with --dart-define=GOOGLE_SIGNIN=true; needs POST /auth/google on the backend.
    throw const AuthException('Google sign-in is not connected yet.');
  }

  @override
  Future<void> logout() async {
    try {
      if (api.tokens.accessToken != null) await api.post('/auth/logout');
    } on ApiException {
      // Already signed out on the server, or offline: still forget the tokens here.
    } finally {
      await api.tokens.clear();
    }
  }

  @override
  Future<PhoneCodeResult> requestPhoneCode(String phoneE164) => _guard(() async {
        final json = await api.post('/auth/phone/request-otp', body: {'phoneNumber': phoneE164});
        final data = ApiClient.dataOf(json);
        final seconds = data['expiresInSeconds'];
        return PhoneCodeResult(
          demoCode: data['devCode'] as String?,
          validFor: Duration(seconds: seconds is num ? seconds.toInt() : 300),
        );
      });

  @override
  Future<void> verifyPhoneCode(String phoneE164, String code) => _guard(() async {
        await api.post('/auth/phone/verify-otp', body: {'phoneNumber': phoneE164, 'otp': code.trim()});
      });

  @override
  Future<void> resendVerificationEmail(String email) => _guard(() async {
        await api.post('/auth/resend-verification', auth: false, body: {'email': email.trim()});
      });

  @override
  Future<void> requestPasswordReset(String email) => _guard(() async {
        await api.post('/auth/password-reset', auth: false, body: {'email': email.trim()});
      });

  @override
  Future<void> resetPassword({required String token, required String newPassword}) => _guard(() async {
        await api.post('/auth/reset-password', auth: false, body: {'token': token, 'password': newPassword});
      });
}
