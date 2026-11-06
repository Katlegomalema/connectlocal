import 'package:flutter/material.dart';

import '../../shared/geocoding.dart';
import '../../shared/map_picker_screen.dart';

import '../models/models.dart' show slotLengthLabel;
import '../state/app_state.dart';
import '../widgets/common_widgets.dart' show EditableAvatar;
import '../../shared/photo_picker.dart';
import 'app_colors.dart';
import 'common.dart';
import 'working_hours_screen.dart';

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

  /// The spot from "Use my current location" / "Choose on map". Null = only a typed address (it is
  /// looked up on Save). Cleared when the provider edits the address by hand.
  GeoPoint? _point;
  bool _locating = false;

  /// Booking options: customers visit the business, and/or the provider does house calls.
  late bool _offersVisit;
  late bool _offersHouseCall;

  @override
  void initState() {
    super.initState();
    // Loaded from the server at sign-in (GET /providers/me).
    final app = AppScope.read(context);
    _name = TextEditingController(text: app.activeProvider.name);
    _description = TextEditingController(text: app.businessDescription);
    _location = TextEditingController(text: app.businessLocation);
    _offersVisit = app.activeProvider.offersVisit;
    _offersHouseCall = app.activeProvider.offersHouseCall;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final (:point, :problem) = await findMyLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    final here = point;
    if (here == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(duration: const Duration(seconds: 5), content: Text(problem ?? 'Location not available.')));
      return;
    }
    setState(() {
      _point = here;
      _location.text = here.label ?? 'My current location';
    });
  }

  Future<void> _chooseOnMap() async {
    final app = AppScope.read(context);
    final p = app.activeProvider;
    final start = _point ??
        (p.latitude != null && p.longitude != null
            ? GeoPoint(p.latitude!, p.longitude!, label: _location.text)
            : null);
    final picked = await pickOnMap(context, initial: start, title: 'Where is your business?');
    if (picked == null || !mounted) return;
    setState(() {
      _point = picked;
      _location.text = picked.label ?? 'Pinned location';
    });
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!_offersVisit && !_offersHouseCall) {
      messenger.showSnackBar(const SnackBar(
          duration: Duration(seconds: 3), content: Text('Choose at least one way customers can book you.')));
      return;
    }
    if (_offersVisit && _location.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(
          duration: Duration(seconds: 3),
          content: Text('Add your business address so customers can find you.')));
      return;
    }
    double? lat;
    double? lng;
    if (_point != null) {
      // From GPS or the map: use that exact spot.
      lat = _point!.latitude;
      lng = _point!.longitude;
    } else if (_location.text.trim() != app.businessLocation.trim()) {
      // A new typed address is looked up so the map pin moves with it.
      final found = await lookupAddress(_location.text);
      final point = found.point;
      if (!mounted) return;
      if (point == null) {
        messenger.showSnackBar(SnackBar(
            duration: const Duration(seconds: 4), content: Text(found.problem ?? 'We couldn\u2019t find that address.')));
        return;
      }
      lat = point.latitude;
      lng = point.longitude;
    }
    // The address first: "Visit the business" needs it on the server.
    final error = await app.updateBusinessProfile(
          name: _name.text,
          description: _description.text,
          location: _location.text,
          latitude: lat,
          longitude: lng,
        ) ??
        await app.setBookingOptions(visit: _offersVisit, houseCall: _offersHouseCall);
    messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 3), content: Text(error ?? 'Changes saved')));
  }

  Widget _option({
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            border: Border.all(color: value ? AppColors.teal : AppColors.borderGrey, width: value ? 1.6 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ],
                ),
              ),
              Checkbox(
                value: value,
                activeColor: AppColors.teal,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {int maxLines = 1, ValueChanged<String>? onChanged}) {
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
          onChanged: onChanged,
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
              _field('Business address', _location, onChanged: (_) {
                if (_point != null) setState(() => _point = null);
              }),
              Wrap(
                children: [
                  TextButton.icon(
                    onPressed: _locating ? null : _useMyLocation,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: Text(_locating ? 'Finding you\u2026' : 'Use my current location'),
                  ),
                  TextButton.icon(
                    onPressed: _locating ? null : _chooseOnMap,
                    icon: Icon(_point == null ? Icons.map_outlined : Icons.check_circle_outline, size: 18),
                    label: Text(_point == null ? 'Choose on map' : 'Location pinned (change)'),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 22),
                child: Text('How customers can book you',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              ),
              _option(
                value: _offersVisit,
                onChanged: (v) => setState(() => _offersVisit = v),
                icon: Icons.storefront_outlined,
                title: 'Customers visit my business',
                subtitle: 'They come to your shop, salon or practice. Your address is shown on a map.',
              ),
              _option(
                value: _offersHouseCall,
                onChanged: (v) => setState(() => _offersHouseCall = v),
                icon: Icons.home_outlined,
                title: 'I do house calls',
                subtitle: 'You go to the customer’s home or current location.',
              ),
              const Padding(
                padding: EdgeInsets.only(top: 22),
                child: Text('When customers can book you',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const WorkingHoursScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderGrey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, color: AppColors.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Working hours & time slots',
                                  style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              const SizedBox(height: 2),
                              Text(
                                '${app.activeProvider.workingHours.days.length} days a week · '
                                '${slotLengthLabel(app.activeProvider.workingHours.slotMinutes)} slots',
                                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textGrey),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              TealButton('Save Changes', height: 46, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
