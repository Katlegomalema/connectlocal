import 'package:flutter/material.dart';

import '../../shared/geocoding.dart';

import '../state/app_state.dart';
import '../widgets/common_widgets.dart' show EditableAvatar;
import '../../shared/photo_picker.dart';
import 'app_colors.dart';
import 'common.dart';

// Screen 30 - Provider Business Profile
// Reached from the storefront icon at the top of the Provider dashboard.
class ProviderBusinessProfileScreen extends StatefulWidget {
  const ProviderBusinessProfileScreen({super.key});

  @override
  State<ProviderBusinessProfileScreen> createState() => _ProviderBusinessProfileScreenState();
}

class _ProviderBusinessProfileScreenState extends State<ProviderBusinessProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _location;

  @override
  void initState() {
    super.initState();
    // Loaded from the server at sign-in (GET /providers/me).
    final app = AppScope.read(context);
    _name = TextEditingController(text: app.activeProvider.name);
    _description = TextEditingController(text: app.businessDescription);
    _location = TextEditingController(text: app.businessLocation);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    double? lat;
    double? lng;
    // A new address is looked up so the map pin moves with it.
    if (_location.text.trim() != app.businessLocation.trim()) {
      final point = await geocodeAddress(_location.text);
      if (!mounted) return;
      if (point == null) {
        messenger.showSnackBar(const SnackBar(duration: Duration(seconds: 3), 
            content: Text('We couldn\u2019t find that address. Add the street, suburb and city.')));
        return;
      }
      lat = point.latitude;
      lng = point.longitude;
    }
    final error = await app.updateBusinessProfile(
      name: _name.text,
      description: _description.text,
      location: _location.text,
      latitude: lat,
      longitude: lng,
    );
    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(error ?? 'Changes saved')));
  }

  Widget _field(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.teal),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => Navigator.maybePop(context),
                child: const Icon(Icons.chevron_left, size: 30, color: AppColors.navy),
              ),
              const SizedBox(height: 20),
              Center(
                child: EditableAvatar(
                  size: 92,
                  photo: app.activeProvider.avatar,
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final picked = await PhotoPicker.pick(context, title: 'Business picture');
                    if (picked.isEmpty) return;
                    final error = await app.setBusinessPhoto(picked.first);
                    if (error != null) {
                      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(error)));
                    }
                  },
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(app.activeProvider.name,
                    style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, size: 11, color: AppColors.teal),
                  const SizedBox(width: 3),
                  Text('${app.activeProvider.rating} (${app.activeProvider.reviews} reviews)',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                ],
              ),
              const SizedBox(height: 10),
              _field('Business Name', _name),
              _field('Description', _description, maxLines: 3),
              _field('Location', _location),
              const SizedBox(height: 40),
              TealButton('Save Changes', height: 46, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
