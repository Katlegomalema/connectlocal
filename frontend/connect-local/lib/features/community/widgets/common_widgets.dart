import 'package:flutter/material.dart';

import '../../shared/photo.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class NavItem {
  final IconData icon;
  final String? label;
  const NavItem(this.icon, {this.label});
}

class AppBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final ValueChanged<int> onTap;
  final int currentIndex;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.onTap,
    this.currentIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Labels are shown only when every item has one.
    final labelled = items.every((i) => i.label != null);
    return BottomNavigationBar(
        currentIndex: currentIndex < 0 ? 0 : currentIndex.clamp(0, items.length - 1).toInt(),
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 16,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.muted,
        showSelectedLabels: labelled,
        showUnselectedLabels: labelled,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          for (final item in items)
            BottomNavigationBarItem(icon: Icon(item.icon), label: item.label ?? ''),
        ],
      );
  }
}

class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const AppSearchField({
    super.key,
    this.controller,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search services near you',
          isDense: true,
        ),
      );
}

class AvatarPlaceholder extends StatelessWidget {
  final double size;
  final bool circle;
  final IconData icon;

  /// A real picture. When set it replaces the icon.
  final PhotoRef? photo;

  /// When there is no photo, show this name's initials instead of an icon.
  final String? label;

  const AvatarPlaceholder({
    super.key,
    this.size = 42,
    this.circle = false,
    this.icon = Icons.image_outlined,
    this.photo,
    this.label,
  });

  String get _initials {
    final words = (label ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.avatarBg,
        borderRadius: circle ? null : BorderRadius.circular(10),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
      ),
      alignment: Alignment.center,
      child: photo != null
          ? PhotoImage(photo, width: size, height: size)
          : (label != null && _initials.isNotEmpty)
              ? Text(_initials,
                  style: TextStyle(
                      fontSize: size * .36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal))
              : Icon(icon, size: size * .48, color: AppColors.avatarIcon),
    );
  }
}

/// Avatar with a small camera badge. Tap it to change the picture.
class EditableAvatar extends StatelessWidget {
  final double size;
  final IconData icon;
  final PhotoRef? photo;
  final VoidCallback onTap;

  const EditableAvatar({
    super.key,
    required this.size,
    required this.onTap,
    this.icon = Icons.person,
    this.photo,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Change profile picture',
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AvatarPlaceholder(size: size, circle: true, icon: icon, photo: photo),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.photo_camera, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class RatingRow extends StatelessWidget {
  final double rating;
  final int reviews;
  const RatingRow({super.key, required this.rating, required this.reviews});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 16, color: AppColors.orange),
            Text(reviews == 0 ? ' New' : ' ${rating.toStringAsFixed(1)}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
            if (reviews > 0)
              Text(' ($reviews reviews)',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      );
}

class ProviderCard extends StatelessWidget {
  final ProviderModel provider;
  final VoidCallback onTap;
  const ProviderCard({
    super.key,
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final service = provider.activeServices.first;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              AvatarPlaceholder(size: 42, photo: provider.displayPhoto, label: provider.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(provider.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                        if (provider.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 16, color: AppColors.teal),
                        ],
                      ],
                    ),
                    RatingRow(rating: provider.rating, reviews: provider.reviews),
                    Text('${service.name} · ${service.priceLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    // Only shown when it is the real GPS distance, never a sample value.
                    if (provider.distanceIsLive)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 13, color: AppColors.teal),
                          const SizedBox(width: 2),
                          Text(distanceLabel(provider.distanceKm),
                              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  final String label;
  final Color? color;
  final bool outlined;
  final double height;
  final double fontSize;
  final VoidCallback? onPressed;

  const PillButton({
    super.key,
    required this.label,
    this.color,
    this.outlined = false,
    this.height = 46,
    this.fontSize = 14,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        // Never smaller than 44 px tall / 14 px text (easy to tap on a phone).
        height: height < 44 ? 44 : height,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color ?? AppColors.teal,
            backgroundColor: outlined ? Colors.transparent : (color ?? AppColors.teal),
            side: BorderSide(color: color ?? AppColors.teal),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            minimumSize: const Size(0, 44),
            visualDensity: VisualDensity.compact,
            shape: const StadiumBorder(),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize < 14 ? 14 : fontSize,
              fontWeight: FontWeight.w600,
              color: outlined ? (color ?? AppColors.teal) : Colors.white,
            ),
          ),
        ),
      );
}
