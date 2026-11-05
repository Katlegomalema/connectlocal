import '../../shared/app_config.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/auth_field.dart';
import '../widgets/common.dart';
import '../../shared/brand.dart';
import '../auth_service.dart';
import '../sign_in_flow.dart';
import 'account_recovery_screens.dart';
import 'register_screen.dart';

// Screen 5 - Login
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _signingIn = false;
  bool _googleSigningIn = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(text)));
  }

  Future<void> _login() async {
    if (_signingIn || _googleSigningIn) return;
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      _message('Please enter your email and password');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _message('Please enter a valid email address');
      return;
    }
    setState(() => _signingIn = true);
    // TODO (backend): authService is the only thing to replace (see auth_service.dart).
    final ok = await runSignIn(
      context,
      () => authService.login(email: email, password: _password.text),
    );
    if (!mounted) return;
    setState(() => _signingIn = false);
    if (!ok) {
      // Wrong details: clear the password and put the cursor back in it so the
      // person can simply type again (no need to refresh).
      _password.clear();
      _passwordFocus.requestFocus();
    }
  }

  Future<void> _google() async {
    if (_signingIn || _googleSigningIn) return;
    setState(() => _googleSigningIn = true);
    await runSignIn(context, authService.signInWithGoogle);
    if (mounted) setState(() => _googleSigningIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              // IntrinsicHeight lets the Spacer push "Create an account" to the
              // bottom on tall screens while still scrolling on short ones.
              child: IntrinsicHeight(
                child: Column(
                children: [
                  const _LoginHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back', style: headingStyle(size: 26)),
                        const SizedBox(height: 6),
                        const Text(
                          'Sign in to find and book trusted local services.',
                          style: TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.4),
                        ),
                        const SizedBox(height: 28),
                        Column(
                            children: [
                              AuthField(
                                hint: 'Email address',
                                icon: Icons.mail_outline_rounded,
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),
                              AuthField(
                                hint: 'Password',
                                icon: Icons.lock_outline_rounded,
                                controller: _password,
                                focusNode: _passwordFocus,
                                isPassword: true,
                              ),
                            ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                            ),
                            child: const Text('Forgot password?',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.teal)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _signingIn
                            ? const SizedBox(
                                height: 52,
                                child: Center(
                                    child: CircularProgressIndicator(color: AppColors.teal)),
                              )
                            : TealButton('Login', height: 52, onPressed: _login),
                        if (AppConfig.googleSignIn) ...[
                        const SizedBox(height: 22),
                        const Row(
                          children: [
                            Expanded(child: Divider(color: AppColors.borderGrey)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or continue with',
                                  style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                            ),
                            Expanded(child: Divider(color: AppColors.borderGrey)),
                          ],
                        ),
                        const SizedBox(height: 22),
                        GoogleButton(onPressed: _google, loading: _googleSigningIn),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('New to Connect Local? ',
                            style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          ),
                          child: const Text('Create an account',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.teal)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft teal-tinted header with the logo. Uses the same teal as the rest of the
/// app, only at low opacity.
class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -40,
            left: -30,
            child: _Bubble(size: 130, alpha: 0.10),
          ),
          Positioned(
            bottom: -50,
            right: -20,
            child: _Bubble(size: 150, alpha: 0.12),
          ),
          Positioned(
            top: 30,
            right: 40,
            child: _Bubble(size: 22, alpha: 0.18),
          ),
          Image.asset('assets/images/splash_logo.png', height: 150),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final double alpha;
  const _Bubble({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.teal.withValues(alpha: alpha),
        ),
      );
}
