import 'package:flutter/material.dart';

import '../community/theme/app_theme.dart' show AppColors;
import 'location_map.dart';

// Colours come from the app palette (AppColors); the customer dot matches the dot drawn on the map.
const _text = AppColors.text;
const _muted = AppColors.muted;
const _customerBlue = kCustomerDotBlue;
const _businessTeal = AppColors.teal;

/// The two maps of a booking. They have different jobs and never replace each other:
///
/// * [CustomerLocationMap]: HOUSE CALL. Where the customer is (their current location, or the spot they
///   pinned), shown as a blue dot. The provider uses it to drive to the customer.
/// * [BusinessLocationMap]: VISIT THE BUSINESS. Where the provider's business physically is, shown as a
///   business pin with the address. The customer uses it to find the business.

/// HOUSE CALL: where the customer is.
class CustomerLocationMap extends StatelessWidget {
  final double latitude;
  final double longitude;

  /// e.g. "Your current location" (customer) or "Customer location" (provider).
  final String title;

  /// The address under the title (optional).
  final String? address;

  /// Shown under the map, e.g. "Get directions to the customer" for the provider. Null = no button.
  final String? directionsLabel;
  final double height;

  const CustomerLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.title = 'Your current location',
    this.address,
    this.directionsLabel,
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MapHeader(
          icon: Icons.my_location,
          color: _customerBlue,
          title: title,
          subtitle: address,
        ),
        const SizedBox(height: 8),
        LocationMap(
          height: height,
          interactive: false,
          pins: const [],
          userLatitude: latitude,
          userLongitude: longitude,
          onTap: directionsLabel == null ? null : () => openDirections(context, latitude, longitude),
        ),
        if (directionsLabel != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => openDirections(context, latitude, longitude),
            icon: const Icon(Icons.directions_outlined, size: 20),
            label: Text(directionsLabel!),
          ),
        ],
      ],
    );
  }
}

/// VISIT THE BUSINESS: where the provider's business is.
class BusinessLocationMap extends StatelessWidget {
  final String businessId;
  final String businessName;
  final String address;
  final double? latitude;
  final double? longitude;

  /// Show "Get directions" (the customer going to the business).
  final bool showDirections;
  final String title;
  final double height;

  const BusinessLocationMap({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.address,
    this.latitude,
    this.longitude,
    this.showDirections = true,
    this.title = 'Business location',
    this.height = 170,
  });

  bool get _hasPin => latitude != null && longitude != null;

  void _directions(BuildContext context) =>
      openDirectionsTo(context, lat: latitude, lng: longitude, address: address);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MapHeader(
          icon: Icons.storefront_outlined,
          color: _businessTeal,
          title: '$title · $businessName',
          subtitle: address.trim().isEmpty ? null : address,
        ),
        if (_hasPin) ...[
          const SizedBox(height: 8),
          LocationMap(
            height: height,
            interactive: false,
            pins: [MapPin(id: businessId, latitude: latitude!, longitude: longitude!, label: businessName)],
            selectedId: businessId,
            onTap: showDirections ? () => _directions(context) : null,
          ),
        ],
        if (showDirections) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _directions(context),
            icon: const Icon(Icons.directions_outlined, size: 20),
            label: const Text('Get directions to the business'),
          ),
        ],
      ],
    );
  }
}

class _MapHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  const _MapHeader({required this.icon, required this.color, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _text)),
              if (subtitle != null && subtitle!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: const TextStyle(fontSize: 13, height: 1.35, color: _muted)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
