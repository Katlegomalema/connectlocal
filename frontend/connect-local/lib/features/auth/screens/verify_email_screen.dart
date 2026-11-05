import 'package:flutter/material.dart';

import '../auth_service.dart';

import '../../community/state/app_state.dart';
import '../../shared/app_config.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';

// Screen 7 - Verify Email
class VerifyEmailScreen extends StatelessWidget {
  // TODO (DB): pass in the email the account was created with
  // Figma shows "conneclocal@email.com" (looks like a typo); using connectlocal@email.com
  final String email;

  const VerifyEmailScreen({super.key, this.email = 'connectlocal@email.com'});

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
                  child: const Icon(Icons.chevron_left, size: 34, color: AppColors.teal),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Image.asset('assets/images/verify_email.png', height: 180),
                    const SizedBox(height: 36),
                    const Text('Verify Your Email',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    const SizedBox(height: 28),
                    const Text("We've sent a verification link to:",
                        style: TextStyle(fontSize: 12, color: AppColors.textDark)),
                    const SizedBox(height: 16),
                    Text(email,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy)),
                    const SizedBox(height: 20),
                    const Text(
                      'Please check your inbox and click the link to activate your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 20),
                    // Testing only (--dart-define=DEV_TOOLS=true): stands in for the
                    // link in the email until the backend sends real emails.
                    if (AppConfig.devTools) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          AppScope.read(context).verifyEmailFor(email);
                          _message(context, 'Email verified. You can log in now.');
                        },
                        icon: const Icon(Icons.mark_email_read_outlined, size: 20),
                        label: const Text('Verify now (dev tools)'),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text("Didn't receive the email?",
                        style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    TextButton(
                      onPressed: () async {
                        try {
                          await authService.resendVerificationEmail(email);
                          if (context.mounted) _message(context, 'If the account is not confirmed yet, a new email is on its way.');
                        } on AuthException catch (e) {
                          if (context.mounted) _message(context, e.message);
                        }
                      },
                      child: const Text('Resend Verification',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.teal)),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already verified? ',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                    ),
                    child: const Text('Login',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.teal)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}