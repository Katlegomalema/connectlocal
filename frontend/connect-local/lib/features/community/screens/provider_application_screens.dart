import 'package:flutter/material.dart';

import '../../shared/figma_ui.dart';
import '../../shared/geocoding.dart';
import '../../shared/map_picker_screen.dart';
import '../../shared/photo.dart';
import '../../shared/photo_picker.dart';
import '../../shared/photo_viewer.dart';
import '../../shared/verification.dart';
import '../state/app_state.dart';

// Figma "Provider App" screens 23 and 24:
//   BecomeProviderScreen -> ApplicationSubmittedScreen
//
// Open it from Profile (for example a "Become a Provider" row):
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const BecomeProviderScreen()));

/// What the user typed on the Become a Provider form. Hand this to your
/// state/backend through [BecomeProviderScreen.onSubmit].
class ProviderApplication {
  final String businessName;
  final String category;
  final String description;
  final String location;
  final String registrationNumber;
  final double latitude;
  final double longitude;
  final PhotoRef registrationDoc;
  final String idNumber;
  final PhotoRef idDoc;
  final List<PhotoRef> portfolio;

  const ProviderApplication({
    required this.businessName,
    required this.category,
    required this.description,
    required this.location,
    required this.registrationNumber,
    required this.latitude,
    required this.longitude,
    required this.registrationDoc,
    required this.idNumber,
    required this.idDoc,
    this.portfolio = const [],
  });

  int get portfolioImageCount => portfolio.length;
}

// ---------------------------------------------------------------------------
// Screen 23: Become a Provider
// ---------------------------------------------------------------------------
class BecomeProviderScreen extends StatefulWidget {
  /// Categories shown in the picker. Replace with the real list from your backend.
  final List<String> categories;

  /// Called with the form data when the user taps Submit Application. Returns an error message to show
  /// (the form stays open), or null when the application was sent.
  final Future<String?> Function(ProviderApplication application)? onSubmit;

  /// What the "Back to Home" button on the confirmation page does. Defaults to
  /// returning to the first screen of the stack.
  final VoidCallback? onDone;

  const BecomeProviderScreen({
    super.key,
    this.categories = const [
      'Plumbing',
      'Cleaning',
      'Tutoring',
      'Electrical',
      'Gardening',
      'Landscaping',
      'Other',
    ],
    this.onSubmit,
    this.onDone,
  });

  @override
  State<BecomeProviderScreen> createState() => _BecomeProviderScreenState();
}

class _BecomeProviderScreenState extends State<BecomeProviderScreen> {
  static const _maxImages = 6;

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _regNumber = TextEditingController();
  PhotoRef? _regDoc;
  final _idNumber = TextEditingController();
  PhotoRef? _idDoc;
  GeoPoint? _point; // from GPS, or found from the address on submit
  bool _busy = false;
  String? _category;
  final List<PhotoRef> _photos = [];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    _regNumber.dispose();
    _idNumber.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in widget.categories)
              ListTile(
                title: Text(c),
                trailing: c == _category
                    ? const Icon(Icons.check, color: FigmaColors.teal)
                    : null,
                onTap: () => Navigator.pop(sheetContext, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _pickRegDoc() async {
    final picked = await PhotoPicker.pick(context,
        max: 1, title: 'Upload registration document', allowDocument: true);
    if (picked.isEmpty || !mounted) return;
    setState(() => _regDoc = picked.first);
  }

  Future<void> _pickIdDoc() async {
    final picked =
        await PhotoPicker.pick(context,
            max: 1, title: 'Photo of your ID document', allowDocument: true);
    if (picked.isEmpty || !mounted) return;
    setState(() => _idDoc = picked.first);
  }

  Future<void> _addImage() async {
    final room = _maxImages - _photos.length;
    if (room <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 3), content: Text('You can add up to 6 images')),
      );
      return;
    }
    final picked = await PhotoPicker.pick(context, max: room, title: 'Add portfolio photos');
    if (picked.isEmpty || !mounted) return;
    setState(() => _photos.addAll(picked));
  }

  Future<void> _useMyLocation() async {
    setState(() => _busy = true);
    final here = await currentLocation();
    if (!mounted) return;
    setState(() => _busy = false);
    if (here == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: const Duration(seconds: 3), 
          content: Text('Couldn\u2019t get your location. Allow location access or type the address.')));
      return;
    }
    setState(() {
      _point = here;
      _location.text = here.label ?? 'My current location';
    });
  }

  Future<void> _chooseOnMap() async {
    final picked = await pickOnMap(context, initial: _point, title: 'Where is your business?');
    if (picked == null || !mounted) return;
    setState(() {
      _point = picked;
      _location.text = picked.label ?? 'Pinned location';
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty ||
        _category == null ||
        _description.text.trim().isEmpty ||
        _location.text.trim().isEmpty ||
        _regNumber.text.trim().isEmpty ||
        _idNumber.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 3), content: Text('Please fill in all the fields')),
      );
      return;
    }
    void warn(String m) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(m)));
    final regProblem = checkRegistrationNumber(_regNumber.text);
    if (regProblem != null) return warn(regProblem);
    if (AppScope.read(context).registrationNumberTaken(_regNumber.text)) {
      return warn('A business with this registration number has already applied');
    }
    final id = parseSaId(_idNumber.text);
    if (id == null) return warn('That South African ID number is not valid');
    if (id.age < 18) return warn('You must be 18 or older to become a provider');
    if (_idDoc == null) return warn('Please upload a photo of your ID document');
    if (_regDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: const Duration(seconds: 3), 
          content: Text('Please upload your business registration document')));
      return;
    }
    // Find the business on the map (customers see it and get directions).
    var point = _point;
    if (point == null || (point.label != null && point.label != _location.text.trim())) {
      setState(() => _busy = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: Duration(seconds: 2), content: Text('Finding your address on the map…')));
      point = await geocodeAddress(_location.text);
      if (!mounted) return;
      setState(() => _busy = false);
      if (point == null) {
        return warn('We couldn\u2019t find that address. Add the street, suburb and city, or tap "Use my current location".');
      }
    }
    final application = ProviderApplication(
      businessName: _name.text.trim(),
      category: _category!,
      description: _description.text.trim(),
      location: _location.text.trim(),
      registrationNumber: _regNumber.text.trim(),
      latitude: point.latitude,
      longitude: point.longitude,
      registrationDoc: _regDoc!,
      idNumber: _idNumber.text.replaceAll(RegExp(r'\s'), ''),
      idDoc: _idDoc!,
      portfolio: List.of(_photos),
    );
    // Uploads the documents/photos and sends the application for admin review.
    setState(() => _busy = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        duration: Duration(seconds: 2), content: Text('Sending your application…')));
    final error = await widget.onSubmit?.call(application);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) return warn(error);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ApplicationSubmittedScreen(onBackToHome: widget.onDone)),
    );
  }

  Widget _selectField({
    required String text,
    required bool isHint,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FigmaColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: isHint ? FigmaColors.body : FigmaColors.title,
                ),
              ),
            ),
            Icon(icon, size: 20, color: FigmaColors.body),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FigmaPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          const Text(
            'Become a Provider',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: FigmaColors.title,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Offer your services and grow your business',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: FigmaColors.body),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: figmaInput('Business Name'),
          ),
          const SizedBox(height: 14),
          _selectField(
            text: _category ?? 'Category',
            isHint: _category == null,
            icon: Icons.arrow_drop_down,
            onTap: _pickCategory,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            minLines: 4,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: figmaInput('Describe your services...'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _point = null,
            decoration: figmaInput('Business address (street, suburb, city)'),
          ),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _chooseOnMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Choose on map'),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _useMyLocation,
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('Use my current location'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _regNumber,
            keyboardType: TextInputType.number,
            decoration: figmaInput('Business registration no. (2019/123456/07)'),
          ),
          const SizedBox(height: 14),
          _selectField(
            text: _regDoc == null
                ? 'Upload registration document'
                : 'Registration document added (tap to replace)',
            isHint: _regDoc == null,
            icon: _regDoc == null ? Icons.upload_file_outlined : Icons.check_circle,
            onTap: _pickRegDoc,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _idNumber,
            keyboardType: TextInputType.number,
            maxLength: 13,
            decoration: figmaInput('Your South African ID number').copyWith(counterText: ''),
          ),
          const SizedBox(height: 14),
          _selectField(
            text: _idDoc == null
                ? 'Upload photo of your ID'
                : 'ID photo added (tap to replace)',
            isHint: _idDoc == null,
            icon: _idDoc == null ? Icons.badge_outlined : Icons.check_circle,
            onTap: _pickIdDoc,
          ),
          const SizedBox(height: 14),
          _selectField(
            text: _photos.isEmpty
                ? 'Upload Portfolio Images'
                : _photos.length == 1
                    ? '1 image added (tap to add more)'
                    : '${_photos.length} images added (tap to add more)',
            isHint: _photos.isEmpty,
            icon: Icons.photo_camera_outlined,
            onTap: _addImage,
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (int i = 0; i < _photos.length; i++)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => showPhotoViewer(context, _photos, initialIndex: i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: PhotoImage(_photos[i], width: 72, height: 72),
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                                color: Colors.black87, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          FigmaButton('Submit Application', onPressed: _submit),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 24: Application Submitted
// ---------------------------------------------------------------------------
class ApplicationSubmittedScreen extends StatelessWidget {
  /// Defaults to returning to the first screen of the stack (Home).
  final VoidCallback? onBackToHome;

  const ApplicationSubmittedScreen({super.key, this.onBackToHome});

  @override
  Widget build(BuildContext context) {
    return FigmaPage(
      showBack: false,
      bottom: FigmaButton(
        'Back to Home',
        onPressed: onBackToHome ?? () => popToRoot(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 70),
          Center(
            child: Image.asset(
              'assets/images/application_submitted.png',
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.mark_email_read_outlined,
                size: 110,
                color: FigmaColors.teal,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Application Submitted!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: FigmaColors.teal,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Your application is being reviewed by our team',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: FigmaColors.body),
          ),
          const SizedBox(height: 24),
          const Text(
            "We'll notify you within 24-48 hours.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: FigmaColors.body),
          ),
        ],
      ),
    );
  }
}


/// Opens the "Become a Provider" form and sends the application to the admin.
void openBecomeProvider(BuildContext context, {VoidCallback? onDone}) {
  final app = AppScope.read(context);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BecomeProviderScreen(
        categories: AppState.categories,
        onDone: onDone,
        onSubmit: (a) => app.sendProviderApplication(
          businessName: a.businessName,
          category: a.category,
          description: a.description,
          location: a.location,
          latitude: a.latitude,
          longitude: a.longitude,
          registrationNumber: a.registrationNumber,
          registrationDoc: a.registrationDoc,
          idNumber: a.idNumber,
          idDoc: a.idDoc,
          photos: a.portfolio,
        ),
      ),
    ),
  );
}
