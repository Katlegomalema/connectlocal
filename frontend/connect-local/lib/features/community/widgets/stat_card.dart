import 'package:flutter/material.dart';

import '../../shared/brand.dart';
import '../theme/app_theme.dart';

/// Small summary tile ("Today's Bookings  1"). Used on the provider
/// dashboard and the analytics screen.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool showStar;
  final IconData? icon;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.showStar = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.teal),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (showStar) ...[
                  const Icon(Icons.star_rounded, size: 22, color: AppColors.orange),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: headingStyle(size: 22, color: AppColors.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
