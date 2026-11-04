import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small rounded teal button (Approve, Reject, Edit, Manage, Disable).
class PillButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const PillButton(this.text, {super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}