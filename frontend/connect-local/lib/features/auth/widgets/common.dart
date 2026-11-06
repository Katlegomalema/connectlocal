import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/busy_button.dart';

import '../theme/app_colors.dart';

/// "< Title" header used at the top of every screen.
class ScreenHeader extends StatelessWidget {
  final String title;
  const ScreenHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.maybePop(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chevron_left, color: AppColors.navy),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width teal rounded button.
class TealButton extends StatelessWidget {
  final String text;
  final FutureOr<void> Function() onPressed;
  final double height;
  const TealButton(this.text, {super.key, required this.onPressed, this.height = 48});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: BusyElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Light grey rounded card.
class GreyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const GreyCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.greyBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// One line of small dark text with space above it.
class InfoLine extends StatelessWidget {
  final String text;
  final double top;
  const InfoLine(this.text, {super.key, this.top = 6});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
    );
  }
}

/// "Continue with Google" button: white, outlined, with the Google "G".
/// Shows a spinner while [loading] and ignores taps.
class GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String label;
  const GoogleButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          // Soft teal tint + teal outline so it belongs to the same family as
          // the teal Login button, while staying clearly secondary.
          backgroundColor: AppColors.teal.withValues(alpha: 0.08),
          foregroundColor: AppColors.navy,
          side: BorderSide(color: AppColors.teal.withValues(alpha: 0.55), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    // TODO (design): swap for the official multicolour Google "G"
                    // asset before release (Google's branding rules).
                    child: const Text('G',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4285F4))),
                  ),
                  const SizedBox(width: 12),
                  Text(label,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }
}
