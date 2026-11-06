import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/busy_button.dart';

import '../../shared/brand.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Shared building blocks so every customer / provider screen looks and feels
/// the same: same card, same chips, same buttons, same empty state.

/// Colour used for a booking status everywhere in the app.
Color bookingStatusColor(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return AppColors.orange;
    case BookingStatus.confirmed:
      return AppColors.green;
    case BookingStatus.completed:
      return AppColors.teal;
    case BookingStatus.declined:
      return AppColors.red;
    case BookingStatus.cancelled:
      return AppColors.muted;
  }
}

/// Colour used for a booking stage (more detailed than the status).
Color bookingStageColor(BookingStage stage) {
  switch (stage) {
    case BookingStage.awaitingProvider:
    case BookingStage.paymentDue:
    case BookingStage.cashPending:
      return AppColors.orange;
    case BookingStage.secured:
      return AppColors.teal;
    case BookingStage.inProgress:
      return AppColors.green;
    case BookingStage.completed:
      return AppColors.green;
    case BookingStage.declined:
      return AppColors.red;
    case BookingStage.cancelled:
      return AppColors.muted;
  }
}

/// Section heading ("Services", "Portfolio", ...).
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(text, style: headingStyle(size: 16, color: AppColors.text)),
          ),
          ?trailing,
        ],
      );
}

/// White rounded card with a hairline border and a soft shadow
/// (same look as the provider cards on the home screen).
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

/// Small coloured pill: "Pending", "Active", "Verified" ...
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, {super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      );
}

/// Small icon + text line ("📅 3 November 2026 · 4:44 PM").
class MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const MetaRow(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ],
      );
}

/// Pill-shaped filter tabs (Upcoming / Past / Pending).
class FilterTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  const FilterTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        // Full width so the tabs start at the left edge, in line with the
        // page content, even inside a centred Column.
        width: double.infinity,
        child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(
                    color: selected == i ? AppColors.teal : AppColors.inputBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected == i ? Colors.white : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      );
}

/// Centered icon + title + message for lists with nothing in them yet.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  const EmptyState({super.key, required this.icon, required this.title, this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.avatarBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: AppColors.teal),
              ),
              const SizedBox(height: 18),
              Text(title,
                  textAlign: TextAlign.center,
                  style: headingStyle(size: 17, color: AppColors.text)),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4)),
              ],
            ],
          ),
        ),
      );
}

/// Full-width teal button (same as the Login button).
class PrimaryButton extends StatelessWidget {
  final String label;
  final FutureOr<void> Function()? onPressed;
  final bool loading;
  final IconData? icon;
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: BusyElevatedButton(
          onPressed: onPressed,
          loading: loading,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.teal.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(label,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
        ),
      );
}

/// Round tinted icon button (chat, call ...).
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Small text under the button so its purpose is always visible.
  final String? label;
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final button = _button();
    if (label == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 3),
        Text(label!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }

  Widget _button() => Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.avatarBg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, size: 20, color: AppColors.teal),
            ),
          ),
        ),
      );
}

/// One booking in a list. Used by both the customer and provider screens.
class BookingCard extends StatelessWidget {
  final String title;
  final String service;
  final String dateText;
  final String priceText;
  final BookingStatus status;

  /// When given, the card shows this more detailed stage instead of the status.
  final BookingStage? stage;
  final Widget? trailing;
  final Widget? footer;
  final VoidCallback? onTap;

  const BookingCard({
    super.key,
    required this.title,
    required this.service,
    required this.dateText,
    required this.priceText,
    required this.status,
    this.stage,
    this.trailing,
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: headingStyle(size: 16, weight: FontWeight.w600, color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(service,
                          style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                      const SizedBox(height: 10),
                      MetaRow(Icons.calendar_today_outlined, dateText),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Total  ',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                Text(priceText,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                const Spacer(),
                StatusChip(stage?.label ?? status.label,
                    color: stage != null ? bookingStageColor(stage!) : bookingStatusColor(status)),
              ],
            ),
            if (footer != null) ...[const SizedBox(height: 14), footer!],
          ],
        ),
      );
}
