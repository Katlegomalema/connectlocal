import 'package:flutter/material.dart';
import '../../shared/photo.dart';
import '../../shared/photo_picker.dart';
import '../../shared/photo_viewer.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';

/// Screen 27: Add Service Form (also used to edit an existing service)
class AddServiceScreen extends StatefulWidget {
  final ServiceModel? service; // null = add, non-null = edit
  const AddServiceScreen({super.key, this.service});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  // Each pricing type keeps its own price, so what is typed under "Per hour" never shows up under
  // "Fixed price" (and vice versa).
  final TextEditingController _hourlyPrice = TextEditingController();
  final TextEditingController _fixedPrice = TextEditingController();
  TextEditingController get _priceCtrl =>
      _type == PricingType.fixed ? _fixedPrice : _hourlyPrice;
  late final TextEditingController _descCtrl;
  String? _category;
  static const _maxPhotos = 6;
  late List<PhotoRef> _photos;

  /// false = one price per hour, true = fixed-price packages (e.g. 1 camera / 3 cameras).
  PricingType _type = PricingType.hourly;
  bool get _usePackages => _type == PricingType.packages;
  final List<_PackageRow> _packageRows = [];


  bool get _editing => widget.service != null;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _category = s?.category;
    _photos = List.of(s?.photos ?? const <PhotoRef>[]);
    if (s != null) {
      _type = s.pricingType;
      if (s.pricingType != PricingType.packages) _priceCtrl.text = '${s.price}';
    }
    if (s != null && s.hasPackages) {
      for (final k in s.packages) {
        _packageRows.add(_PackageRow(k.name, '${k.price}', k.description));
      }
    }
    if (_packageRows.isEmpty) _packageRows.add(_PackageRow('', '', ''));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hourlyPrice.dispose();
    _fixedPrice.dispose();
    _descCtrl.dispose();
    for (final r in _packageRows) {
      r.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(String hint, {String? prefixText}) =>
      InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.muted),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      );

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text.rich(
          TextSpan(
            text: text,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
            children: [
              if (required)
                const TextSpan(
                    text: ' *', style: TextStyle(color: AppColors.red)),
            ],
          ),
        ),
      );

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  int? _parsePrice() =>
      int.tryParse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

  Future<void> _addPhotos() async {
    final room = _maxPhotos - _photos.length;
    if (room <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: Duration(seconds: 3), content: Text('You can add up to 6 photos')),
      );
      return;
    }
    final picked = await PhotoPicker.pick(context, max: room, title: 'Add photos');
    if (picked.isEmpty || !mounted) return;
    setState(() => _photos.addAll(picked));
  }

  bool _saving = false;

  Future<void> _publish() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final packages = <ServicePackage>[];
    if (_usePackages) {
      for (final r in _packageRows) {
        final price = r.price;
        if (r.name.text.trim().isEmpty && price == null) continue;
        if (r.name.text.trim().isEmpty || price == null || price <= 0) {
          messenger.showSnackBar(const SnackBar(duration: Duration(seconds: 3), 
              content: Text('Each package needs a name and a price')));
          return;
        }
        packages.add(ServicePackage(
            name: r.name.text.trim(),
            price: price,
            description: r.description.text.trim()));
      }
      if (packages.isEmpty) {
        messenger.showSnackBar(const SnackBar(duration: Duration(seconds: 3), content: Text('Add at least one package')));
        return;
      }
    }
    // With packages the service price is the cheapest package ("From R...").
    final price = _usePackages
        ? packages.map((k) => k.price).reduce((a, b) => a < b ? a : b)
        : _parsePrice()!;

    // Saved on the server when connected (the list reloads from there), else on this device.
    setState(() => _saving = true);
    final error = await app.saveService(
      widget.service,
      name: _nameCtrl.text.trim(),
      category: _category!,
      price: price,
      description: _descCtrl.text.trim(),
      photos: _photos,
      packages: packages,
      pricingType: _type,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(error)));
      return;
    }
    final navigator = Navigator.of(context);
    navigator.pop();
    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), 
      content: Text(_editing ? 'Service updated' : 'Service published'),
      action: _editing
          ? null
          : SnackBarAction(
              label: 'Add another',
              onPressed: () => navigator.push(
                MaterialPageRoute(builder: (_) => const AddServiceScreen()),
              ),
            ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Service' : 'Add New Service'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Add one service at a time, each with its own price. For example a barber adds '
                    '"Men\u2019s haircut" and "Beard trim" as two services. After publishing you can '
                    'tap "Add another". Your business name and description come from your application.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
                  ),
                ),
                _label('Service Name', required: true),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: _decoration('e.g. Men\u2019s haircut, Geyser repair, Maths lesson'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final business = AppScope.read(context).activeProvider.name;
                    if (v.trim().toLowerCase() == business.trim().toLowerCase()) {
                      return 'Use the name of the service (e.g. "Men\u2019s haircut"), not your business name';
                    }
                    return null;
                  },
                ),
                _label('Category', required: true),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                  decoration: _decoration('Select a category'),
                  items: [
                    for (final c in AppState.categories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                _label('How do you price this service?', required: true),
                SegmentedButton<PricingType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: PricingType.hourly, label: Text('Per hour')),
                    ButtonSegment(value: PricingType.fixed, label: Text('Fixed price')),
                    ButtonSegment(value: PricingType.packages, label: Text('Packages')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (v) => setState(() => _type = v.first),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    switch (_type) {
                      PricingType.hourly =>
                        'For work that takes a variable time, e.g. tutoring or plumbing repairs. '
                        'The customer chooses how many hours.',
                      PricingType.fixed =>
                        'One price for the whole job, e.g. a haircut R80 or a car wash R150.',
                      PricingType.packages =>
                        'A few options the customer chooses from, e.g. "Cut R80" or "Cut + beard R120".',
                    },
                    style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted),
                  ),
                ),
                if (!_usePackages) ...[
                  _label(_type == PricingType.fixed ? 'Price (R)' : 'Price (R/hour)', required: true),
                  TextFormField(
                    key: ValueKey('price-${_type.name}'),
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14),
                    decoration: _decoration('350', prefixText: 'R '),
                    validator: (v) {
                      if (_usePackages) return null;
                      final p = _parsePrice();
                      if (p == null || p <= 0) return 'Enter a valid price';
                      return null;
                    },
                  ),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Example: "Cut" R80, "Cut + beard" R120. Each package has its own price.',
                      style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
                    ),
                  ),
                  for (var i = 0; i < _packageRows.length; i++)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.hairline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('Package ${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text)),
                              ),
                              if (_packageRows.length > 1)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Remove package',
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () => setState(() {
                                    _packageRows.removeAt(i).dispose();
                                  }),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _packageRows[i].name,
                            style: const TextStyle(fontSize: 14),
                            decoration: _decoration('Name, e.g. Cut + beard'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _packageRows[i].priceText,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14),
                            decoration: _decoration('Price', prefixText: 'R '),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _packageRows[i].description,
                            style: const TextStyle(fontSize: 14),
                            decoration: _decoration('What is included (optional)'),
                          ),
                        ],
                      ),
                    ),
                  if (_packageRows.length < 6)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _packageRows.add(_PackageRow('', '', ''))),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Add another package'),
                      ),
                    ),
                ],
                _label('What does this service include?', required: true),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14),
                  decoration: _decoration('Describe this service only, e.g. what the customer gets...'),
                  validator: _requiredValidator,
                ),
                _label('Photos'),
                InkWell(
                  onTap: _addPhotos,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_a_photo_outlined,
                            size: 18, color: AppColors.teal),
                        const SizedBox(width: 8),
                        Text(
                          _photos.isEmpty
                              ? 'Add photos of your work'
                              : 'Add more (${_photos.length}/$_maxPhotos)',
                          style: const TextStyle(fontSize: 14, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
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
                              child: AvatarPlaceholder(size: 72, photo: _photos[i]),
                            ),
                            Positioned(
                              right: -6,
                              top: -6,
                              child: GestureDetector(
                                onTap: () => setState(() => _photos.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: AppColors.text, shape: BoxShape.circle),
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
                PrimaryButton(
                  _editing ? 'Save Changes' : 'Publish Service',
                  onPressed: _saving ? null : _publish,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// The text boxes of one package in the Add Service form.
class _PackageRow {
  final TextEditingController name;
  final TextEditingController priceText;
  final TextEditingController description;

  _PackageRow(String n, String p, String d)
      : name = TextEditingController(text: n),
        priceText = TextEditingController(text: p),
        description = TextEditingController(text: d);

  int? get price => int.tryParse(priceText.text.replaceAll(RegExp(r'[^0-9]'), ''));

  void dispose() {
    name.dispose();
    priceText.dispose();
    description.dispose();
  }
}
