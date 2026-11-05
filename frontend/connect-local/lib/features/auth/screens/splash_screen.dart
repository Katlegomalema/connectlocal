import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'onboarding_screen.dart';

// Screen 1 - Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // TODO: check if the user is already logged in and skip onboarding
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B2447), Color(0xFF1F5FA8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              Image.asset('assets/images/splash_logo.png', width: 150),
              const SizedBox(height: 28),
              const Text(
                'Local services, trusted connections',
                style: TextStyle(fontSize: 13, color: Color(0xFF9DB9E0)),
              ),
              const Spacer(flex: 3),
              const CupertinoActivityIndicator(color: Colors.white, radius: 16),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}