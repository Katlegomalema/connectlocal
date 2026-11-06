import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'ui_kit.dart';

/// "Reviews" list: stars, comment, first name, service and date.
class ReviewsSection extends StatelessWidget {
  final List<ReviewItem> reviews;
  final String emptyText;
  const ReviewsSection({
    super.key,
    required this.reviews,
    this.emptyText = 'No written reviews yet.',
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      SectionTitle(reviews.isEmpty ? 'Reviews' : 'Reviews (${reviews.length})'),
      const SizedBox(height: 12),
    ];
    if (reviews.isEmpty) {
      children.add(AppCard(
        child: Text(emptyText,
            style: const TextStyle(fontSize: 14, color: AppColors.muted)),
      ));
    }
    for (final b in reviews) {
      final first = b.customerFirstName;
      final comment = b.comment.trim();
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= b.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 20,
                      color: AppColors.orange,
                    ),
                  const Spacer(),
                  Text(formatDate(b.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(comment,
                    style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.text)),
              ],
              const SizedBox(height: 8),
              Text(b.serviceName.isEmpty ? first : '$first · ${b.serviceName}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              if ((b.providerResponse ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Reply: ${b.providerResponse!.trim()}',
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.text)),
              ],
            ],
          ),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
