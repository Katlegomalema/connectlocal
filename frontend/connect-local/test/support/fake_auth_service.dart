import 'package:connect_local/features/auth/auth_service.dart';

/// Widget tests only: an [AuthService] that never talks to a server. The real app always uses
/// ApiAuthService (there is no offline sign-in any more).
class FakeAuthService implements AuthService {
  final List<String> registered = [];

  @override
  Future<AuthResult> login({required String email, required String password}) async =>
      AuthResult(userId: 'test-user', name: 'Test User', email: email);

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    bool offersServices = false,
  }) async =>
      registered.add(email);

  @override
  Future<void> logout() async {}

  @override
  Future<PhoneCodeResult> requestPhoneCode(String phoneE164) async => const PhoneCodeResult(demoCode: '123456');

  @override
  Future<void> verifyPhoneCode(String phoneE164, String code) async {
    if (code != '123456') throw const AuthException('Wrong code.');
  }

  @override
  Future<void> resendVerificationEmail(String email) async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> resetPassword({required String token, required String newPassword}) async {}

  @override
  Future<AuthResult> signInWithGoogle() async => throw const AuthException('Not available in tests.');
}
