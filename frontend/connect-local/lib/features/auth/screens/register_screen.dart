import 'package:flutter/material.dart';

import '../../community/state/app_state.dart';
import '../../shared/app_config.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_field.dart';
import '../widgets/common.dart';
import '../auth_service.dart';
import '../sign_in_flow.dart';
import 'verify_email_screen.dart';

/// Password rules shared with the backend (see backend/src/utils/validators.js).
class RegisterScreenRules {
  RegisterScreenRules._();
  static String? problem(String password) => _RegisterScreenState.passwordProblem(password);
}

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
  bool _submitting = false;

  // One focus node and one error per box, so a mistake is shown under the right box and the cursor goes
  // straight back into it.
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  /// false = "I need a service", true = "I offer a service".
  bool _offersServices = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// Same rules as the backend, so the person sees them before sending.
  static String? passwordProblem(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) return 'Add at least one capital letter (A-Z)';
    if (!RegExp(r'[a-z]').hasMatch(password)) return 'Add at least one small letter (a-z)';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Add at least one number (0-9)';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) return 'Add at least one symbol, e.g. ! @ # ?';
    return null;
  }

  /// Live check of the confirmation: once it is as long as the password, say straight away whether they
  /// match (instead of only after SIGN UP).
  void _recheckConfirm() {
    final confirm = _confirm.text;
    final password = _password.text;
    setState(() {
      if (confirm.isEmpty) {
        _confirmError = null;
      } else if (confirm == password) {
        _confirmError = null;
      } else if (confirm.length >= password.length || !password.startsWith(confirm)) {
        _confirmError = 'Passwords do not match';
      } else {
        _confirmError = null; // still typing, so far so good
      }
    });
  }

  /// Puts the cursor back in [focus] with the text selected, ready to fix.
  void _focusField(FocusNode focus, TextEditingController controller) {
    focus.requestFocus();
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
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
    if (_submitting) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    setState(() {
      _nameError = name.length < 2 ? 'Please enter your full name' : null;
      _emailError = email.isEmpty
          ? 'Please enter your email address'
          : (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? 'Please enter a valid email address' : null);
      _passwordError = passwordProblem(password);
      _confirmError = _confirm.text.isEmpty
          ? 'Please type your password again'
          : (_confirm.text != password ? 'Passwords do not match' : null);
    });
    // Jump to the first box with a problem.
    final firstProblem = [
      if (_nameError != null) (_nameFocus, _name),
      if (_emailError != null) (_emailFocus, _email),
      if (_passwordError != null) (_passwordFocus, _password),
      if (_confirmError != null) (_confirmFocus, _confirm),
    ].firstOrNull;
    if (firstProblem != null) {
      _focusField(firstProblem.$1, firstProblem.$2);
      return;
    }

    final app = AppScope.read(context);
    setState(() => _submitting = true);
    try {
      await authService.register(
        name: name,
        email: email,
        password: password,
        offersServices: _offersServices,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // Put a server answer under the box it is about; anything else as a message.
      final text = e.message.toLowerCase();
      if (text.contains('password')) {
        setState(() => _passwordError = e.message);
        _focusField(_passwordFocus, _password);
      } else if (text.contains('email')) {
        setState(() => _emailError = e.message);
        _focusField(_emailFocus, _email);
      } else {
        _message(e.message);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    app.providerSignupIntent = _offersServices;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email)),
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
                    AuthField(
                      hint: 'Full Name',
                      controller: _name,
                      focusNode: _nameFocus,
                      errorText: _nameError,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() => _nameError = null),
                    ),
                    const SizedBox(height: 16),
                    AuthField(
                      hint: 'Email Address',
                      controller: _email,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() => _emailError = null),
                    ),
                    const SizedBox(height: 16),
                    AuthField(
                      hint: 'Password',
                      controller: _password,
                      focusNode: _passwordFocus,
                      isPassword: true,
                      errorText: _passwordError,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        setState(() => _passwordError = null);
                        if (_confirm.text.isNotEmpty) _recheckConfirm();
                      },
                    ),
                    if (_passwordError == null)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 6, 14, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'At least 8 characters, with a capital letter, a small letter, a number and a symbol.',
                            style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    AuthField(
                      hint: 'Confirm Password',
                      controller: _confirm,
                      focusNode: _confirmFocus,
                      isPassword: true,
                      showEye: false,
                      errorText: _confirmError,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signUp(),
                      onChanged: (_) => _recheckConfirm(),
                    ),
                    const SizedBox(height: 28),
                    TealButton(_submitting ? 'CREATING ACCOUNT…' : 'SIGN UP', onPressed: _signUp),
                    if (AppConfig.googleSignIn) ...[
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
