import 'package:flutter/material.dart';

import '../../community/screens/verify_phone_screen.dart';
import '../../shared/geocoding.dart';
import '../../shared/map_picker_screen.dart';
import '../../community/state/app_state.dart';
import '../../community/models/models.dart' show kBookingFeeRate, bookingFeeFor, ServicePackage;
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
  final int hourlyRate;

  /// Fixed-price options of the service (empty = priced per hour).
  final List<ServicePackage> packages;

  /// One fixed price for the whole service (e.g. a haircut): no duration.
  final bool fixedPrice;

  const BookingScreen({
    super.key,
    this.providerId = 'provider-1',
    this.providerName = 'Bobs Plumbing',
    this.serviceId = 'service-1',
    this.serviceName = 'Pipe repair',
    this.hourlyRate = 350,
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
  final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late DateTime _date = _today;
  String? _time; // null until the user picks a slot
  final _notes = TextEditingController();
  final _address = TextEditingController();
  bool _addressReady = false;

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
      if (picked.label != null && picked.label!.isNotEmpty) _address.text = picked.label!;
    });
  }
  int _hours = 1;
  int _package = 0;

  bool get _hasPackages => widget.packages.isNotEmpty;
  bool get _fixed => widget.fixedPrice && !_hasPackages;
  ServicePackage? get _chosenPackage => _hasPackages ? widget.packages[_package] : null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start with the address the customer used last time.
    if (!_addressReady) {
      _addressReady = true;
      _address.text = AppScope.of(context).customerAddress;
    }
  }

  int get _serviceTotal => _hasPackages
      ? _chosenPackage!.price
      : _fixed
          ? widget.hourlyRate
          : widget.hourlyRate * _hours;
  int get _fee => bookingFeeFor(_serviceTotal);

  String get _dateText => '${_date.day} ${_months[_date.month - 1]} ${_date.year}';

  bool get _isToday => DateUtils.isSameDay(_date, _today);

  /// "2:00 PM" -> minutes since midnight.
  static int _minutesOf(String slot) {
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false)
        .firstMatch(slot)!;
    var hour = int.parse(m.group(1)!);
    final isPm = m.group(3)!.toUpperCase() == 'PM';
    if (isPm && hour < 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    return hour * 60 + int.parse(m.group(2)!);
  }

  /// A slot can't be booked if it is already in the past (only matters today).
  bool _isPast(String slot) {
    if (!_isToday) return false;
    final now = DateTime.now();
    return _minutesOf(slot) <= now.hour * 60 + now.minute;
  }

  @override
  void dispose() {
    _notes.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          alwaysUse24HourFormat: false,
          textScaler: TextScaler.noScaling,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.teal),
          ),
          child: child!,
        ),
      ),
    );
    if (picked == null) return;
    final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
    final minute = picked.minute.toString().padLeft(2, '0');
    final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
    final slot = '$hour:$minute $period';
    if (!mounted) return;
    if (_isPast(slot)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 3), content: Text('That time has already passed. Pick a later time.')),
      );
      return;
    }
    setState(() => _time = slot);
  }

  void _confirm() {
    if (_time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 3), content: Text('Please choose a preferred time')),
      );
      return;
    }
    if (_isPast(_time!)) {
      setState(() => _time = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 3), content: Text('That time has already passed. Please select another.')),
      );
      return;
    }
    if (_address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 3), content: Text('Enter the address where the service is needed')),
      );
      return;
    }
    // Only genuine, verified customers can book.
    if (!AppScope.read(context).emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 3), content: Text('Please verify your email address before booking (Profile shows your verification status).')),
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
            time: _time!,
            address: _address.text.trim(),
            latitude: _lat,
            longitude: _lng,
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
              _label('Select Date', top: 20),
              Theme(
                data: theme.copyWith(
                  colorScheme: theme.colorScheme
                      .copyWith(primary: AppColors.teal, onPrimary: Colors.white),
                ),
                child: CalendarDatePicker(
                  initialDate: _today,
                  firstDate: _today,
                  lastDate: _today.add(const Duration(days: 365)),
                  onDateChanged: (d) => setState(() {
                    _date = d;
                    if (_time != null && _isPast(_time!)) _time = null;
                  }),
                ),
              ),
              _label('Preferred Time', top: 8),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickCustomTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: _time == null ? AppColors.borderGrey : AppColors.teal),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 20, color: AppColors.teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _time ?? 'Choose the time you want the provider to arrive',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: _time == null ? FontWeight.w400 : FontWeight.w600,
                              color: _time == null ? AppColors.textGrey : AppColors.textDark),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: AppColors.textGrey),
                    ],
                  ),
                ),
              ),

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
                            Text('R${widget.packages[i].price}',
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
                      Text('R${widget.hourlyRate}',
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
                    _stepButton(Icons.remove, _hours > 1 ? () => setState(() => _hours--) : null),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(_hours == 1 ? '1 hour' : '$_hours hours',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                    ),
                    _stepButton(Icons.add, _hours < 8 ? () => setState(() => _hours++) : null),
                    const Spacer(),
                    Text('R${widget.hourlyRate}/hour',
                        style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
                  ],
                ),
              ],

              _label('Service Address'),
              const SizedBox(height: 8),
              TextField(
                controller: _address,
                // Typing by hand replaces any spot chosen on the map.
                onChanged: (_) {
                  if (_lat != null) setState(() { _lat = null; _lng = null; });
                },
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Where should the provider come?',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                  prefixIcon: const Icon(Icons.location_on_outlined,
                      size: 20, color: AppColors.teal),
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
              OutlinedButton.icon(
                onPressed: _chooseOnMap,
                icon: Icon(_lat == null ? Icons.map_outlined : Icons.check_circle_outline, size: 20),
                label: Text(_lat == null ? 'Choose on map' : 'Location pinned (change)'),
              ),

              _label('Additional Notes'),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
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
                                : 'Service (R${widget.hourlyRate} × $_hours ${_hours == 1 ? 'hour' : 'hours'})',
                        'R$_serviceTotal'),

                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Divider(height: 1),
                    ),
                    _priceRow('Pay now (${(kBookingFeeRate * 100).round()}% deposit)', 'R$_fee',
                        bold: true, color: AppColors.teal),
                    _priceRow('Pay after the service is done', 'R${_serviceTotal - _fee}'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your request goes to the provider first. Your deposit counts toward the price and is refunded if they decline.',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              TealButton('Pay R$_fee deposit', height: 52, onPressed: _confirm),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}