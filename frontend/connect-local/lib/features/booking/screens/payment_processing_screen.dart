import 'package:flutter/material.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../models/booking_request.dart';
import '../payment_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'booking_confirmation_screen.dart';

// Screen 37 - Card payment via PayFast
//
// Two uses:
//  * [request]    - the customer pays the deposit; on success the booking
//                   request is created and sent to the provider.
//  * [balanceFor] - the customer pays the service cost for an accepted booking.
class PaymentProcessingScreen extends StatefulWidget {
  final BookingRequest? request;
  final Booking? balanceFor;

  /// How the customer chose to pay (always an online PayFast method here).
  final PayMethod method;

  const PaymentProcessingScreen(
      {super.key, this.request, this.balanceFor, this.method = PayMethod.card})
      : assert(request != null || balanceFor != null);

  @override
  State<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  bool _failed = false;
  String? _message;

  int get _amount => widget.request?.fee ?? widget.balanceFor!.balance;
  String get _item => widget.request != null
      ? 'Booking fee: ${widget.request!.serviceName}'
      : 'Service: ${widget.balanceFor!.serviceName}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pay());
  }

  Future<void> _pay() async {
    setState(() => _failed = false);
    final app = AppScope.read(context);
    final result = await paymentService.payWithCard(PaymentRequest(
      reference: 'CL-${DateTime.now().millisecondsSinceEpoch}',
      amountRand: _amount,
      itemName: _item,
      customerName: app.customerName,
      customerEmail: app.customerEmail,
      method: switch (widget.method) {
        PayMethod.instantEft => 'eft',
        PayMethod.applePay => 'apple',
        PayMethod.samsungPay => 'sp',
        PayMethod.capitecPay => 'cp',
        PayMethod.scanToPay => 'mp',
        PayMethod.mobicred => 'mc',
        _ => 'cc',
      },
    ));
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _failed = true;
        _message = result.message ?? 'The payment was not completed.';
      });
      return;
    }
    final gatewayReference = result.gatewayReference ?? 'PF-UNKNOWN';

    final request = widget.request;
    if (request != null) {
      final bookingId = app.addCustomerBooking(
        providerId: request.providerId,
        serviceId: request.serviceId,
        serviceName: request.serviceName,
        date: request.date,
        time: request.time,
        hourlyRate: request.hourlyRate,
        hours: request.hours,
        packageName: request.packageName,
        address: request.address,
        atBusiness: request.atBusiness,
        blockedMinutes: request.blockedMinutes,
        latitude: request.latitude,
        longitude: request.longitude,
        notes: request.notes,
        paymentReference: gatewayReference,
        feeMethod: widget.method,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmationScreen(
            bookingId: bookingId,
            transactionId: gatewayReference,
            request: request,
          ),
        ),
      );
      return;
    }

    // Paying the service cost: go back to the booking's detail page.
    final booking = widget.balanceFor!;
    app.payBalance(booking, method: widget.method, reference: gatewayReference);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context)
        .popUntil((r) => r.settings.name == 'booking-detail' || r.isFirst);
    messenger.showSnackBar(
      SnackBar(duration: const Duration(seconds: 3), content: Text('Payment of R${booking.balance} received. Thank you!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _failed, // don't leave mid-payment
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
                Text(_failed ? 'Payment not completed' : 'Processing payment…',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 12),
                Text(
                  _failed
                      ? (_message ?? 'Something went wrong.')
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
                      InfoLine('Total now: R$_amount', top: 10),
                      InfoLine('Method: ${widget.method.label}', top: 10),
                    ],
                  ),
                ),
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
