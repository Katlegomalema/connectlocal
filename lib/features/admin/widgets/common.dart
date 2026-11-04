import 'package:flutter/material.dart';

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
  final VoidCallback onPressed;
  final double height;
  const TealButton(this.text, {super.key, required this.onPressed, this.height = 48});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
      child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
    );
  }
}