import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

class _OnboardingPage {
  final String image;
  final String title;
  final String text;
  const _OnboardingPage(this.image, this.title, this.text);
}

// Screens 2-4 - Onboarding 1, 2 and 3
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    _OnboardingPage('assets/images/onboarding_map.png', 'Find Local Services',
        'Discover trusted providers in your area instantly.'),
    _OnboardingPage('assets/images/onboarding_book.png', 'Book Instantly',
        'Schedule appointments with just one tap. No calls.'),
    _OnboardingPage('assets/images/onboarding_chat.png', 'Chat with Providers',
        'Ask questions and get real-time updates.'),
  ];

  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip >',
                    style: TextStyle(fontSize: 12, color: AppColors.textDark)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Column(
                    children: [
                      const Spacer(flex: 2),
                      Image.asset(p.image, height: 190),
                      const SizedBox(height: 40),
                      Text(p.title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy)),
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(p.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
                      ),
                      const Spacer(flex: 3),
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index ? AppColors.teal : AppColors.borderGrey,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 36),
            if (last)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TealButton('Get Started', onPressed: _next),
              )
            else
              SizedBox(width: 130, child: TealButton('Next', height: 44, onPressed: _next)),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}