import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showArrow;
  final Color? iconColor;

  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.showArrow = true,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        icon,
        size: 23,
        color: iconColor ?? AppTheme.muted,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.text,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: showArrow
          ? const Icon(
        Icons.chevron_right,
        size: 20,
        color: AppTheme.muted,
      )
          : null,
      onTap: onTap,
      minTileHeight: 48,
    );
  }
}