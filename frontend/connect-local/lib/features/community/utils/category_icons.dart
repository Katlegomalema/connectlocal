import 'package:flutter/material.dart';

/// One icon per ConnectLocal category (same list as AppState.kCategories). Used on the home screen and
/// on the admin site, so a category looks the same everywhere.
const Map<String, IconData> kCategoryIcons = {
  'Beauty & Health': Icons.spa_rounded,
  'Healthcare': Icons.medical_services_rounded,
  'Plumbing': Icons.plumbing_rounded,
  'Cleaning Services': Icons.cleaning_services_rounded,
  'Education & Tutoring': Icons.school_rounded,
  'Automotive Services': Icons.car_repair_rounded,
  'Electrical Services': Icons.electrical_services_rounded,
  'Events & Photography': Icons.photo_camera_rounded,
  'Home Maintenance': Icons.handyman_rounded,
  'Other': Icons.more_horiz_rounded,
};

/// The icon for [category] ("ALL" = every category); a neutral icon for names not in the list.
IconData categoryIcon(String category) {
  if (category == 'ALL') return Icons.apps_rounded;
  for (final e in kCategoryIcons.entries) {
    if (e.key.toLowerCase() == category.trim().toLowerCase()) return e.value;
  }
  return Icons.category_rounded;
}
