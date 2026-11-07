import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/payment_keys.dart';
import '../../community/utils/format.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../models/booking_request.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'booking_confirmation_screen.dart';

// Screen 37 - Card payment via PayFast
//
// Two uses:
//  * [request]    - the customer pays the deposit; on success the booking
//                   request is created and sent to the provider.
//  * [balanceFor] - the customer pays the service cost for an accepted booking.
//  * [feeFor]     - finish paying the booking fee of a request made earlier (app closed mid-payment).
//
// Never charges twice: every "start payment" sends the same Idempotency-Key (core/payment_keys.dart), so
// "Try again", a slow network or reopening the app always gets the SAME payment back from the server.
class PaymentProcessingScreen extends StatefulWidget {
  final BookingRequest? request;
  final Booking? balanceFor;
  final Booking? feeFor;

  /// How the customer chose to pay (always an online PayFast method here).
  final PayMethod method;

  const PaymentProcessingScreen(
      {super.key, this.request, this.balanceFor, this.feeFor, this.method = PayMethod.card})
      : assert(request != null || balanceFor != null || feeFor != null);

  @override
  State<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> with WidgetsBindingObserver {
  bool _failed = false;
  bool _starting = false;
  String? _message;

  // ---- server (PayFast sandbox) ----
  Booking? _serverBooking; // created once, reused on "Try again"
  String? _paymentId;
  String? _checkoutUrl;
  bool _waiting = false; // PayFast is open; polling the payment status
  Timer? _poll;
  DateTime? _pollStarted;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  /// Back from the PayFast tab / browser: check straight away instead of waiting for the next poll.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final booking = _serverBooking ?? widget.balanceFor;
    if (state == AppLifecycleState.resumed && _waiting && booking != null) {
      _checkPayment(AppScope.read(context), booking);
    }
  }

  bool get _isFee => widget.request != null || widget.feeFor != null;
  String get _purpose => _isFee ? 'booking_fee' : 'balance';

  double get _amount => widget.request?.fee ?? widget.feeFor?.bookingFee ?? widget.balanceFor!.balance;
  String get _item => widget.request != null
      ? 'Booking fee: ${widget.request!.serviceName}'
      : widget.feeFor != null
          ? 'Booking fee: ${widget.feeFor!.serviceName}'
          : 'Service: ${widget.balanceFor!.serviceName}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _serverBooking = widget.feeFor;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pay());
  }

  Future<void> _pay() async {
    setState(() => _failed = false);
    await _payOnServer(AppScope.read(context));
  }

  /// Real flow: booking on the server -> signed PayFast checkout -> browser -> poll until the ITN arrived.
  Future<void> _payOnServer(AppState app) async {
    if (_starting) return; // "Try again" tapped twice
    _poll?.cancel();
    setState(() {
      _starting = true;
      _failed = false;
      _waiting = false;
    });
    try {
      final request = widget.request;
      final booking = widget.balanceFor ??
          (_serverBooking ??= await app.createServerBooking(
            providerId: request!.providerId,
            serviceId: request.serviceId,
            date: request.date,
            time: request.time,
            hours: request.hours,
            address: request.address,
            atBusiness: request.atBusiness,
            packageName: request.packageName,
            latitude: request.latitude,
            longitude: request.longitude,
            notes: request.notes,
          ));
      // Same Idempotency-Key every time: the server returns the same payment (or says it is already paid).
      final started = await app.repository!.startPayment(booking.id, _purpose);
      _paymentId = started.paymentId;
      _checkoutUrl = started.checkoutUrl;
      if (started.alreadyPaid) {
        if (mounted) setState(() => _starting = false);
        await _onPaid(app, booking, started.paymentId);
        return;
      }
      await _openCheckout();
      if (!mounted) return;
      setState(() => _waiting = true);
      _pollStarted = DateTime.now();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _checkPayment(app, booking));
      if (mounted) setState(() => _starting = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _failed = true;
        _message = e.isNetwork
            ? '${e.message} You were not charged twice: tapping "Try again" continues the same payment.'
            : e.message;
      });
    }
  }

  Future<void> _openCheckout() async {
    final url = _checkoutUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  }

  Future<void> _checkPayment(AppState app, Booking booking) async {
    final paymentId = _paymentId;
    if (paymentId == null || !mounted) return;
    ({String status, String? reference}) state;
    try {
      state = await app.repository!.paymentStatus(paymentId);
    } on ApiException {
      return; // try again on the next tick
    }
    if (!mounted) return;
    if (state.status == 'paid') {
      _poll?.cancel();
      await _onPaid(app, booking, state.reference ?? paymentId);
    } else if (state.status == 'failed') {
      _poll?.cancel();
      setState(() {
        _waiting = false;
        _failed = true;
        _message = 'PayFast did not complete the payment. Nothing was charged.';
      });
    } else if (DateTime.now().difference(_pollStarted!) > const Duration(minutes: 15)) {
      _poll?.cancel();
      setState(() {
        _waiting = false;
        _failed = true;
        _message = 'We have not heard from PayFast yet. If you paid, it will show on the booking shortly.';
      });
    }
  }

  Future<void> _onPaid(AppState app, Booking booking, String reference) async {
    await PaymentKeys.forget(booking.id, _purpose);
    try {
      await app.reloadBooking(booking.id);
    } on ApiException {
      // the booking list refreshes later anyway
    }
    if (!mounted) return;
    final request = widget.request;
    if (widget.feeFor != null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('Booking fee of ${money(booking.bookingFee)} received. The provider can now accept.')));
      return;
    }
    if (request != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmationScreen(bookingId: booking.id, transactionId: reference, request: request),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((r) => r.settings.name == 'booking-detail' || r.isFirst);
    messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 3), content: Text('Payment of ${money(booking.balance)} received. Thank you!')));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _failed || _waiting, // don't leave while starting; leaving while PayFast is open is fine
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 80),
                if (_failed)
                  const Icon(Icons.error_outline_rounded, size: 96, color: AppColors.cancelRed)
                else
                  Image.asset('assets/images/payment_processing.png', height: 180),
                const SizedBox(height: 40),
                Text(_failed ? 'Payment not completed' : (_waiting ? 'Waiting for PayFast…' : 'Processing payment…'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 12),
                Text(
                  _failed
                      ? (_message ?? 'Something went wrong.')
                      : _waiting
                          ? 'Finish the payment on the PayFast page that opened. This screen updates by itself once '
                              'PayFast confirms it.'
                          : 'Taking you to PayFast to confirm your payment. Please don’t close the app.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textDark),
                ),
                const SizedBox(height: 24),
                GreyCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoLine(_item, top: 0),
                      InfoLine('Total now: ${money(_amount)}', top: 10),
                      InfoLine('Method: ${widget.method.label}', top: 10),
                    ],
                  ),
                ),
                if (_waiting) ...[
                  const SizedBox(height: 24),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  TealButton('Open PayFast again', onPressed: _openCheckout),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('I\u2019ll finish later'),
                  ),
                ],
                if (_failed) ...[
                  const SizedBox(height: 24),
                  TealButton('Try again', onPressed: _pay),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
