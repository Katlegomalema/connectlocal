import '../../shared/sa_time.dart';
import 'package:flutter/material.dart';

import '../../shared/validators.dart';
import '../../community/utils/format.dart';

import '../../community/screens/verify_phone_screen.dart';
import '../../shared/geocoding.dart';
import '../../shared/booking_maps.dart';
import '../../shared/map_picker_screen.dart';
import '../../community/state/app_state.dart';
import '../../community/models/models.dart'
    show kBookingFeeRate, bookingFeeFor, clockLabel, ProviderModel, ServicePackage;
import '../models/booking_request.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'payment_method_screen.dart';

// Screen 14 - Booking Screen
class BookingScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String serviceId;
  final String serviceName;
  final double hourlyRate;

  /// Fixed-price options of the service (empty = priced per hour).
  final List<ServicePackage> packages;

  /// One fixed price for the whole service (e.g. a haircut).
  final bool fixedPrice;

  const BookingScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.serviceId,
    required this.serviceName,
    required this.hourlyRate,
    this.packages = const [],
    this.fixedPrice = false,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final DateTime _today = DateUtils.dateOnly(nowSast()); // booking days are South African days
  late DateTime _date = _today;

  /// The booked time slot (start). Null until the customer picks a free slot.
  DateTime? _slot;
  final _notes = TextEditingController();
  final _address = TextEditingController();
  bool _addressReady = false;

  @override
  void initState() {
    super.initState();
    // Fresh working hours and taken times from the server (another customer may just have booked).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final error = await AppScope.read(context).loadSchedule(widget.providerId);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(error)));
        return;
      }
      // The hours may have changed: start on a day the provider works, unless a slot is already picked.
      if (_slot == null) setState(() => _date = _firstOpenDay() ?? _today);
    });
  }

  /// The spot the customer chose on the map (cleared if they edit the address by hand).
  double? _lat;
  double? _lng;

  Future<void> _chooseOnMap() async {
    final start = (_lat != null && _lng != null) ? GeoPoint(_lat!, _lng!, label: _address.text) : null;
    final picked = await pickOnMap(context, initial: start, title: 'Where should the provider come?');
    if (picked == null || !mounted) return;
    setState(() {
      _lat = picked.latitude;
      _lng = picked.longitude;
      _fromGps = false;
      if (picked.label != null && picked.label!.isNotEmpty) _address.text = picked.label!;
    });
  }
  bool _locating = false;

  /// True when [_lat]/[_lng] came from the phone's GPS (false = a spot the customer pinned on the map).
  bool _fromGps = false;

  /// House call: find the customer's current location (GPS) and fill in the address.
  /// [auto] = started by choosing "Request a house call" (a softer message if it fails).
  Future<void> _useMyLocation({bool auto = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    final (:point, :problem) = await findMyLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    final here = point;
    if (here == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(problem ?? 'We couldn’t find your current location. Type your address or choose it on the map.')));
      return;
    }
    setState(() {
      _lat = here.latitude;
      _lng = here.longitude;
      _fromGps = true;
      _address.text = here.label ?? 'My current location';
    });
  }

  /// The customer chose (or was given) the house call option: show where they are right away.
  void _selectHouseCall() {
    setState(() => _atBusiness = false);
    if (_lat == null) _useMyLocation(auto: true);
  }

  int _hours = 1;
  int _package = 0;

  /// How the customer gets the service: true = visit the business / salon, false = house call,
  /// null = not chosen yet (only when the provider offers both).
  bool? _atBusiness;

  bool get _hasPackages => widget.packages.isNotEmpty;
  bool get _fixed => widget.fixedPrice && !_hasPackages;
  ServicePackage? get _chosenPackage => _hasPackages ? widget.packages[_package] : null;

  ProviderModel get _provider => AppScope.read(context).providerById(widget.providerId);

  /// "Visit the business" needs the provider to allow it and a place customers can find.
  bool get _canVisit => _provider.canBeVisited;

  /// House calls are the fallback when a business cannot be visited, so there is always one option.
  bool get _canHouseCall => _provider.offersHouseCall || !_canVisit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_addressReady) {
      _addressReady = true;
      // Start with the address the customer used last time.
      _address.text = AppScope.of(context).customerAddress;
      // Start on the first day the provider works (today if open).
      _date = _firstOpenDay() ?? _today;
      // Only one option offered: choose it for the customer.
      if (_canVisit != _canHouseCall) {
        _atBusiness = _canVisit;
        // House call only: find the customer's current location once the screen is shown.
        if (!_canVisit) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _selectHouseCall(); });
      }
    }
  }

  double get _serviceTotal => _hasPackages
      ? _chosenPackage!.price
      : _fixed
          ? widget.hourlyRate
          : widget.hourlyRate * _hours;
  double get _fee => bookingFeeFor(_serviceTotal);

  String get _dateText => '${_date.day} ${_months[_date.month - 1]} ${_date.year}';

  /// How long the booking holds the provider's time: one slot, or the hours of a per-hour service.
  int get _blockedMinutes =>
      (_hasPackages || _fixed) ? _provider.workingHours.slotMinutes : _hours * 60;

  /// First day from today (within a year) on which the provider works, or null if they never do.
  DateTime? _firstOpenDay() {
    final hours = _provider.workingHours;
    for (var i = 0; i < 366; i++) {
      final day = _today.add(Duration(days: i));
      if (hours.isOpenOn(day)) return day;
    }
    return null;
  }

  /// "10:00 AM" for the booking summary.
  String get _timeText => clockLabel(_slot!.hour * 60 + _slot!.minute);

  @override
  void dispose() {
    _notes.dispose();
    _address.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_atBusiness == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            duration: Duration(seconds: 3),
            content: Text('Choose how you want the service: visit the business or request a house call')),
      );
      return;
    }
    if (_slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: Duration(seconds: 3), content: Text('Please choose a time slot')),
      );
      return;
    }
    // Checked again now: the slot may have been taken or passed since it was shown.
    if (!_slot!.isAfter(nowSast()) ||
        !AppScope.read(context).slotIsFree(widget.providerId, _slot!, _blockedMinutes)) {
      setState(() => _slot = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            duration: Duration(seconds: 3),
            content: Text('That time slot is no longer available. Please choose another.')),
      );
      return;
    }
    final atBusiness = _atBusiness!;
    final textProblem = (!atBusiness ? Validators.address(_address.text) : null) ??
        Validators.text(_notes.text, max: 1000, label: 'Notes');
    if (textProblem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 3), content: Text(textProblem)),
      );
      return;
    }
    // Only genuine, verified customers can book.
    if (!AppScope.read(context).emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: Duration(seconds: 3), content: Text('Please verify your email address before booking (Profile shows your verification status).')),
      );
      return;
    }
    // The provider needs a reachable, verified number.
    if (AppScope.read(context).verifiedPhone == null) {
      _askToVerifyPhone();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(
          request: BookingRequest(
            providerId: widget.providerId,
            providerName: widget.providerName,
            serviceId: widget.serviceId,
            serviceName: widget.serviceName,
            hourlyRate: _hasPackages ? _chosenPackage!.price : widget.hourlyRate,
            hours: (_hasPackages || _fixed) ? 1 : _hours,
            packageName: _hasPackages ? _chosenPackage!.name : (_fixed ? 'Fixed price' : null),
            date: _dateText,
            time: _timeText,
            atBusiness: atBusiness,
            blockedMinutes: _blockedMinutes,
            address: atBusiness ? _provider.address : _address.text.trim(),
            latitude: atBusiness ? null : _lat,
            longitude: atBusiness ? null : _lng,
            notes: _notes.text.trim(),
          ),
        ),
      ),
    );
  }

  Future<void> _askToVerifyPhone() async {
    final verify = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify your phone number'),
        content: const Text(
            'Your provider needs a verified number to contact you about this booking.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verify now')),
        ],
      ),
    );
    if (verify == true && mounted) {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const VerifyPhoneScreen()));
    }
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: onTap == null ? AppColors.borderGrey : AppColors.teal),
          ),
          child: Icon(icon,
              size: 20, color: onTap == null ? AppColors.borderGrey : AppColors.teal),
        ),
      );

  Widget _priceRow(String label, String value, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                      color: color ?? AppColors.textDark)),
            ),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: color ?? AppColors.textDark)),
          ],
        ),
      );

  /// After the booked length changes (more hours), drop the chosen slot if it no longer fits.
  void _keepSlotIfFree() {
    final slot = _slot;
    if (slot != null && !AppScope.read(context).slotIsFree(widget.providerId, slot, _blockedMinutes)) {
      _slot = null;
    }
  }

  /// The time slots of the chosen day: free ones can be picked, booked ones are shown but disabled.
  List<Widget> _slotSection() {
    final app = AppScope.of(context);
    final slotLength = _provider.workingHours.slotMinutes;
    final slots = app.slotsFor(widget.providerId, _date, _blockedMinutes);
    return [
      _label(_atBusiness == true ? 'Arrival time slot' : 'Time slot', top: 8),
      const SizedBox(height: 8),
      if (slots.isEmpty)
        const Text('No time slots left on this day. Please choose another day.',
            style: TextStyle(fontSize: 13, color: AppColors.textGrey))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in slots)
              () {
                final label = clockLabel(s.start.hour * 60 + s.start.minute);
                // Booked = another booking overlaps this slot; otherwise it is just too close to closing
                // time for the hours chosen.
                final booked = !app.slotIsFree(widget.providerId, s.start, slotLength);
                return ChoiceChip(
                  label: Text(s.free ? label : '$label \u00b7 ${booked ? 'Booked' : 'Too late'}'),
                  selected: _slot == s.start,
                  selectedColor: AppColors.teal.withValues(alpha: 0.15),
                  onSelected: s.free ? (_) => setState(() => _slot = s.start) : null,
                );
              }(),
          ],
        ),
      if (!_hasPackages && !_fixed && _hours > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('$_hours hours from the slot you choose are reserved for you.',
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ),
    ];
  }

  /// One of the two booking options. [onTap] null = the only option (shown as chosen, not tappable).
  Widget _optionCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.teal.withValues(alpha: 0.05) : Colors.white,
            border: Border.all(
                color: selected ? AppColors.teal : AppColors.borderGrey, width: selected ? 1.6 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.teal, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.textGrey)),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? AppColors.teal : AppColors.textGrey),
            ],
          ),
        ),
      ),
    );
  }

  /// "How would you like to get this service?" with the options this provider offers.
  List<Widget> _optionSection() {
    final both = _canVisit && _canHouseCall;
    return [
      _label(both ? 'How would you like to get this service?' : 'How this service works', top: 20),
      const SizedBox(height: 8),
      if (_canVisit)
        _optionCard(
          selected: _atBusiness == true,
          icon: Icons.storefront_outlined,
          title: 'Visit the business',
          subtitle: 'Go to ${widget.providerName}’s premises (shop, salon or practice).',
          onTap: both ? () => setState(() => _atBusiness = true) : null,
        ),
      if (_canHouseCall)
        _optionCard(
          selected: _atBusiness == false,
          icon: Icons.home_outlined,
          title: 'Request a house call',
          subtitle: 'The provider comes to your home or current location.',
          onTap: both ? _selectHouseCall : null,
        ),
    ];
  }

  /// Visit: the Business Location Map (where the provider's business physically is).
  List<Widget> _businessLocationSection() {
    final p = _provider;
    return [
      _label('Where to go'),
      const SizedBox(height: 8),
      BusinessLocationMap(
        businessId: p.id,
        businessName: p.name,
        address: p.address,
        latitude: p.latitude,
        longitude: p.longitude,
      ),
    ];
  }

  /// House call: where the provider must come.
  List<Widget> _houseCallAddressSection() => [
        _label('Your address'),
        const SizedBox(height: 8),
        ValidatedField(
          controller: _address,
          validator: Validators.address,
          // Typing by hand replaces any spot chosen on the map.
          onChanged: (_) {
            if (_lat != null) setState(() { _lat = null; _lng = null; _fromGps = false; });
          },
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Where should the provider come?',
            hintStyle: const TextStyle(fontSize: 14, color: AppColors.textGrey),
            prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: AppColors.teal),
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: _locating ? null : _useMyLocation,
              icon: const Icon(Icons.my_location, size: 20),
              label: Text(_locating ? 'Finding you…' : 'Use my current location'),
            ),
            OutlinedButton.icon(
              onPressed: _chooseOnMap,
              icon: Icon(_lat == null ? Icons.map_outlined : Icons.check_circle_outline, size: 20),
              label: Text(_lat == null ? 'Choose on map' : 'Location pinned (change)'),
            ),
          ],
        ),
        // The Customer Location Map: where the provider will come.
        if (_locating)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Finding your current location…', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
            ]),
          )
        else if (_lat != null && _lng != null) ...[
          const SizedBox(height: 10),
          CustomerLocationMap(
            latitude: _lat!,
            longitude: _lng!,
            title: _fromGps ? 'Your current location' : 'Your pinned location',
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Your house call request goes to ${widget.providerName}. They accept or decline it; '
          'if they decline, your booking fee is refunded.',
          style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textGrey),
        ),
      ];

  Widget _label(String text, {double top = 16}) => Padding(
    padding: EdgeInsets.only(top: top),
    child: Text(text,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader('Book Service'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderGrey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.providerName} - ${widget.serviceName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ),
              ..._optionSection(),
              _label('Select Date', top: 20),
              if (_firstOpenDay() == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('This provider has not set any working days yet, so they cannot be booked.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                )
              else ...[
                Theme(
                  data: theme.copyWith(
                    colorScheme: theme.colorScheme
                        .copyWith(primary: AppColors.teal, onPrimary: Colors.white),
                  ),
                  child: CalendarDatePicker(
                    initialDate: _date,
                    firstDate: _today,
                    lastDate: _today.add(const Duration(days: 365)),
                    // Only days the provider works can be chosen.
                    selectableDayPredicate: _provider.workingHours.isOpenOn,
                    onDateChanged: (d) => setState(() {
                      _date = d;
                      _slot = null;
                    }),
                  ),
                ),
                ..._slotSection(),
              ],

              if (_hasPackages) ...[
                _label('Choose a package'),
                const SizedBox(height: 8),
                for (var i = 0; i < widget.packages.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _package = i),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _package == i ? AppColors.teal.withValues(alpha: 0.05) : Colors.white,
                          border: Border.all(
                              color: _package == i ? AppColors.teal : AppColors.borderGrey,
                              width: _package == i ? 1.6 : 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                                _package == i
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: _package == i ? AppColors.teal : AppColors.textGrey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.packages[i].name,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark)),
                                  if (widget.packages[i].description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(widget.packages[i].description,
                                          style: const TextStyle(
                                              fontSize: 13, height: 1.35, color: AppColors.textGrey)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(money(widget.packages[i].price),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.teal)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ] else if (_fixed) ...[
                _label('Price'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.05),
                    border: Border.all(color: AppColors.teal, width: 1.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(widget.serviceName,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark)),
                      ),
                      Text(money(widget.hourlyRate),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teal)),
                    ],
                  ),
                ),
              ] else ...[
                _label('Duration'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _stepButton(Icons.remove, _hours > 1 ? () => setState(() { _hours--; _keepSlotIfFree(); }) : null),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(_hours == 1 ? '1 hour' : '$_hours hours',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                    ),
                    _stepButton(Icons.add, _hours < 8 ? () => setState(() { _hours++; _keepSlotIfFree(); }) : null),
                    const Spacer(),
                    Text('${money(widget.hourlyRate)}/hour',
                        style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
                  ],
                ),
              ],

              if (_atBusiness == true) ..._businessLocationSection(),
              if (_atBusiness == false) ..._houseCallAddressSection(),

              _label('Additional Notes'),
              const SizedBox(height: 8),
              ValidatedField(
                controller: _notes,
                validator: (v) => Validators.text(v, max: 1000, label: 'Notes'),
                maxLines: 4,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Any special requests?',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderGrey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.teal),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 8),
                child: Text('PRICE SUMMARY',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              ),
              GreyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _priceRow(
                        _hasPackages
                            ? 'Service (${_chosenPackage!.name})'
                            : _fixed
                                ? 'Service (${widget.serviceName})'
                                : 'Service (${money(widget.hourlyRate)} × $_hours ${_hours == 1 ? 'hour' : 'hours'})',
                        money(_serviceTotal)),

                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Divider(height: 1),
                    ),
                    _priceRow('Booking fee now (${(kBookingFeeRate * 100).round()}%, refundable)', money(_fee),
                        bold: true, color: AppColors.teal),
                    _priceRow('Pay after the service is done', money(_serviceTotal - _fee)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'The booking fee secures your time slot while the business reviews your request. It counts toward the price and is refunded if they decline.',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              TealButton(
                  _atBusiness == false ? 'Send request · Pay ${money(_fee)} booking fee' : 'Pay ${money(_fee)} booking fee',
                  height: 52,
                  onPressed: _confirm),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}