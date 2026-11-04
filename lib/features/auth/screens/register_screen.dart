import 'package:flutter/material.dart';

import '../../community/state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_field.dart';
import '../widgets/common.dart';
import '../auth_service.dart';
import '../sign_in_flow.dart';
import 'verify_email_screen.dart';

// Screen 6 - Register
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _googleSigningIn = false;

  /// false = "I need a service", true = "I offer a service".
  bool _offersServices = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(text)));
  }

  Future<void> _google() async {
    if (_googleSigningIn) return;
    FocusScope.of(context).unfocus();
    setState(() => _googleSigningIn = true);
    AppScope.read(context).providerSignupIntent = _offersServices;
    await runSignIn(context, authService.signInWithGoogle);
    if (mounted) setState(() => _googleSigningIn = false);
  }

  Future<void> _signUp() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirm.text.isEmpty) {
      _message('Please fill in all fields');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      _message('Please enter a valid email address');
      return;
    }
    if (_password.text.length < 8) {
      _message('Password must be at least 8 characters');
      return;
    }
    if (_password.text != _confirm.text) {
      _message('Passwords do not match');
      return;
    }
    final app = AppScope.read(context);
    try {
      await authService.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      if (mounted) _message(e.message);
      return;
    }
    app.providerSignupIntent = _offersServices;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: _email.text.trim())),
    );
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    const Text('Create Account',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 8),
                    const Text('Join ConnectLocal today',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 24),
                    _RoleChoice(
                      offersServices: _offersServices,
                      onChanged: (v) => setState(() => _offersServices = v),
                    ),
                    const SizedBox(height: 24),
                    AuthField(hint: 'Full Name', controller: _name),
                    const SizedBox(height: 16),
                    AuthField(
                      hint: 'Email Address',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    AuthField(hint: 'Password', controller: _password, isPassword: true),
                    const SizedBox(height: 16),
                    AuthField(
                      hint: 'Confirm Password',
                      controller: _confirm,
                      isPassword: true,
                      showEye: false,
                    ),
                    const SizedBox(height: 28),
                    TealButton('SIGN UP', onPressed: _signUp),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.textDark, thickness: 0.6)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('OR',
                              style: TextStyle(fontSize: 11, color: AppColors.textDark)),
                        ),
                        Expanded(child: Divider(color: AppColors.textDark, thickness: 0.6)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GoogleButton(onPressed: _google, loading: _googleSigningIn),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ',
                      style: TextStyle(fontSize: 12, color: AppColors.textDark)),
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
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

/// "I need a service" / "I offer a service" – decides where the person lands
/// after their first sign-in. Both are the same kind of account.
class _RoleChoice extends StatelessWidget {
  final bool offersServices;
  final ValueChanged<bool> onChanged;
  const _RoleChoice({required this.offersServices, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget card(bool value, IconData icon, String title, String subtitle) {
      final selected = offersServices == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? AppColors.teal.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? AppColors.teal : AppColors.borderGrey,
                  width: selected ? 2 : 1),
            ),
            child: Column(
              children: [
                Icon(icon, color: selected ? AppColors.teal : AppColors.textGrey, size: 28),
                const SizedBox(height: 8),
                Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.teal : AppColors.navy)),
                const SizedBox(height: 4),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
        ),
      );
    }

    // IntrinsicHeight: the page scrolls (unbounded height), so "stretch" needs it
    // to make both cards the same height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card(false, Icons.search_rounded, 'I need a service', 'Find and book local providers'),
          const SizedBox(width: 12),
          card(true, Icons.handyman_outlined, 'I offer a service', 'Get verified and receive bookings'),
        ],
      ),
    );
  }
}
