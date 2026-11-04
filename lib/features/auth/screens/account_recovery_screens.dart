import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../shared/figma_ui.dart';

// Figma "Part 1" screens 8, 9, 10:
//   ForgotPasswordScreen  -> CheckEmailScreen -> (email link) -> CreateNewPasswordScreen
//
// Open ForgotPasswordScreen from the "Forgot password?" link on Login:
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));

bool _looksLikeEmail(String value) {
  final v = value.trim();
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
}

// ---------------------------------------------------------------------------
// Screen 8: Reset Password
// ---------------------------------------------------------------------------
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    final email = _email.text.trim();
    if (!_looksLikeEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 3), content: Text('Please enter a valid email address')),
      );
      return;
    }
    // TODO (backend): request the password-reset email for [email].
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckEmailScreen(email: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FigmaPage(
      bottom: FigmaLinkLine(
        prefix: 'Remember your password?',
        link: 'Login',
        onTap: () => Navigator.maybePop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Reset Password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: FigmaColors.title,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Enter your email address and we'll send you a password reset link.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.4, color: FigmaColors.body),
          ),
          const SizedBox(height: 36),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _send(),
            decoration: figmaInput('Email Address'),
          ),
          const SizedBox(height: 24),
          FigmaButton('Send Reset Link', onPressed: _send),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 9: Check Your Email
// ---------------------------------------------------------------------------
class CheckEmailScreen extends StatelessWidget {
  final String email;

  const CheckEmailScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return FigmaPage(
      bottom: FigmaLinkLine(
        link: 'Return to Login',
        underline: true,
        onTap: () => popToRoot(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Image.asset(
              'assets/images/reset_mailbox.png',
              height: 170,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.mark_email_unread_outlined,
                size: 120,
                color: FigmaColors.teal,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Check Your Email',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: FigmaColors.title,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "We've sent a password reset link to:",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: FigmaColors.body),
          ),
          const SizedBox(height: 12),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: FigmaColors.body,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Click the link to create a new password.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: FigmaColors.body),
          ),
          const SizedBox(height: 56),
          const Text(
            "Didn't receive the email?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: FigmaColors.body,
            ),
          ),
          const SizedBox(height: 6),
          FigmaLinkLine(
            link: 'Resend Link',
            underline: true,
            onTap: () {
              // TODO (backend): resend the reset email.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(duration: const Duration(seconds: 3), content: Text('Reset link sent again')),
              );
            },
          ),
          // In the real app the user taps the link inside the email, which
          // opens CreateNewPasswordScreen. This shortcut exists only so the
          // flow can be tested without a backend, and is hidden in release builds.
          if (kDebugMode) ...[
            const SizedBox(height: 28),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateNewPasswordScreen(),
                ),
              ),
              child: const Text('Demo only: open the reset link'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 10: Create New Password
// ---------------------------------------------------------------------------
class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({super.key});

  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _hasLength => _password.text.length >= 8;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_password.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_password.text);

  void _update() {
    final messenger = ScaffoldMessenger.of(context);
    if (!(_hasLength && _hasUpper && _hasNumber)) {
      messenger.showSnackBar(
        const SnackBar(duration: const Duration(seconds: 3), content: Text('Password does not meet the requirements')),
      );
      return;
    }
    if (_password.text != _confirm.text) {
      messenger.showSnackBar(
        const SnackBar(duration: const Duration(seconds: 3), content: Text('Passwords do not match')),
      );
      return;
    }
    // TODO (backend): save the new password using the token from the email link.
    popToRoot(context);
    messenger.showSnackBar(
      const SnackBar(duration: const Duration(seconds: 3), content: Text('Password updated. Please log in.')),
    );
  }

  Widget _rule(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (met)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.check, size: 16, color: FigmaColors.teal),
            ),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: met ? FigmaColors.teal : FigmaColors.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eye(bool hidden, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: FigmaColors.body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FigmaPage(
      bottom: FigmaLinkLine(
        prefix: 'Remember your password?',
        link: 'Login',
        onTap: () => popToRoot(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Create New Password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: FigmaColors.title,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Enter your new password below.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: FigmaColors.body),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _password,
            obscureText: _hidePassword,
            onChanged: (_) => setState(() {}),
            decoration: figmaInput(
              'New Password',
              suffixIcon: _eye(
                _hidePassword,
                () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirm,
            obscureText: _hideConfirm,
            onSubmitted: (_) => _update(),
            decoration: figmaInput(
              'Confirm Password',
              suffixIcon: _eye(
                _hideConfirm,
                () => setState(() => _hideConfirm = !_hideConfirm),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Password Requirements:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FigmaColors.body,
            ),
          ),
          const SizedBox(height: 6),
          _rule('At least 8 characters', _hasLength),
          _rule('At least one uppercase letter', _hasUpper),
          _rule('At least one number', _hasNumber),
          const SizedBox(height: 28),
          FigmaButton('Update Password', onPressed: _update),
        ],
      ),
    );
  }
}
