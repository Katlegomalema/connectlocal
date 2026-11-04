import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../community/theme/app_theme.dart';
import '../../community/widgets/ui_kit.dart';
import '../../shared/brand.dart';
import 'admin_dashboard_screen.dart';

// Screen 31 - Admin Login
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(text)));
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _message('Please enter your email and password');
      return;
    }
    // TODO (backend): the server must check that this is an admin account.
    final AuthResult result;
    try {
      result = await authService.login(email: _email.text.trim(), password: _password.text);
    } on AuthException catch (e) {
      if (mounted) _message(e.message);
      return;
    }
    if (!mounted) return;
    if (!result.isAdmin) {
      _message('This account does not have admin access');
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
    );
  }

  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              children: [
                Image.asset('assets/images/admin_logo.png', width: 96),
                const SizedBox(height: 20),
                Text('Admin panel', style: headingStyle(size: 22, color: AppColors.text)),
                const SizedBox(height: 6),
                const Text('Sign in with your admin account',
                    style: TextStyle(fontSize: 14, color: AppColors.muted)),
                const SizedBox(height: 28),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: _hidden,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryButton('Log in', onPressed: _login),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
