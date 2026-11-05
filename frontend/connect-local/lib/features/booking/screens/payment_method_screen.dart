import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../models/booking_request.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'payment_processing_screen.dart';

// Screen 35 - Choose how to pay
//
//  * New request  ([request])    : the deposit is ALWAYS paid by card (PayFast).
//  * Finished job ([balanceFor]) : the service cost is paid by card (PayFast) or cash,
//    AFTER the provider completed the job.
class PaymentMethodScreen extends StatefulWidget {
  /// A new request: the customer pays the deposit now.
  final BookingRequest? request;

  /// An accepted booking: the customer pays the service cost.
  final Booking? balanceFor;

  const PaymentMethodScreen({super.key, this.request, this.balanceFor})
      : assert(request != null || balanceFor != null);

  int get amount => request?.fee ?? balanceFor!.balance;
  bool get isFee => request != null;

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  late PayMethod _selected = PayMethod.card;

  /// Apple Pay only exists on Apple devices.
  static bool get _applePayAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Samsung Pay only exists on Android phones.
  static bool get _samsungPayAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _continue() {
    if (_selected == PayMethod.cash) {
      // Cash: nothing to process online. It is recorded as "pending" until the
      // provider confirms they received it.
      final booking = widget.balanceFor!;
      AppScope.read(context).payBalance(booking, method: PayMethod.cash);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context)
          .popUntil((r) => r.settings.name == 'booking-detail' || r.isFirst);
      messenger.showSnackBar(
        SnackBar(duration: const Duration(seconds: 3), content: Text('Cash selected. Hand R${booking.balance} to your provider; they will confirm they received it.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentProcessingScreen(
          request: widget.request,
          balanceFor: widget.balanceFor,
          method: _selected,
        ),
      ),
    );
  }

  static String _shortName(PayMethod m) => switch (m) {
        PayMethod.card => 'card',
        PayMethod.instantEft => 'Instant EFT',
        PayMethod.applePay => 'Apple Pay',
        PayMethod.samsungPay => 'Samsung Pay',
        PayMethod.capitecPay => 'Capitec Pay',
        PayMethod.scanToPay => 'Scan to Pay',
        PayMethod.mobicred => 'Mobicred',
        PayMethod.cash => 'cash',
      };

  Widget _option(PayMethod method, IconData icon, String title, String subtitle) {
    final selected = _selected == method;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selected = method),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppColors.teal.withValues(alpha: 0.05) : Colors.white,
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.borderGrey,
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 28, color: selected ? AppColors.teal : AppColors.textGrey),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13, height: 1.35, color: AppColors.textGrey)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? AppColors.teal : AppColors.textGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cash = _selected == PayMethod.cash;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(widget.isFee ? 'Pay Booking Fee' : 'Pay Remaining Balance'),
              const SizedBox(height: 14),
              if (widget.isFee)
                _BookingFeeExplainer(request: widget.request!)
              else
                GreyCard(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Remaining balance',
                            style: TextStyle(fontSize: 14, color: AppColors.textDark)),
                      ),
                      Text('R${widget.amount}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teal)),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              const Text('How would you like to pay?',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              _option(
                PayMethod.card,
                Icons.credit_card_rounded,
                'Credit or debit card',
                'Visa or Mastercard. Your card details are entered on PayFast, never in this app.',
              ),
              _option(
                PayMethod.instantEft,
                Icons.account_balance_outlined,
                'Instant EFT',
                'Pay straight from your bank account. You log in to your bank on PayFast’s secure page.',
              ),
              if (_applePayAvailable)
                _option(
                  PayMethod.applePay,
                  Icons.phone_iphone_rounded,
                  'Apple Pay',
                  'Pay with Face ID or Touch ID using a card in your Apple Wallet.',
                ),
              if (_samsungPayAvailable)
                _option(
                  PayMethod.samsungPay,
                  Icons.phone_android_rounded,
                  'Samsung Pay',
                  'Pay with a card saved in Samsung Wallet.',
                ),
              _option(
                PayMethod.capitecPay,
                Icons.account_balance_wallet_outlined,
                'Capitec Pay',
                'Approve the payment in your Capitec banking app. No card needed.',
              ),
              _option(
                PayMethod.scanToPay,
                Icons.qr_code_scanner_rounded,
                'Scan to Pay',
                'Pay with SnapScan, Zapper or Masterpass by scanning a QR code on PayFast.',
              ),
              _option(
                PayMethod.mobicred,
                Icons.credit_score_outlined,
                'Mobicred',
                'Use your Mobicred account (pay later, monthly).',
              ),
              if (!widget.isFee)
                _option(
                  PayMethod.cash,
                  Icons.payments_outlined,
                  'Cash',
                  'Hand the cash to your provider now that the job is done. They confirm they received it.',
                ),
              if (widget.isFee)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text(
                    'The booking fee is always paid online. You pay the remaining balance after the service is done, '
                    'by card, Instant EFT, Capitec Pay, Scan to Pay or cash.',
                    style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textGrey),
                  ),
                ),
              const SizedBox(height: 28),
              TealButton(cash ? 'Pay R${widget.amount} in cash' : 'Pay R${widget.amount} with ${_shortName(_selected)}',
                  onPressed: _continue),
              const SizedBox(height: 14),
              const Center(
                child: Text('Secured by PayFast',
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains the booking fee before the customer pays it: what it is, that it secures the time slot, and
/// when it is refunded. Matches the rules in AppState (refund on decline / cancel while pending).
class _BookingFeeExplainer extends StatelessWidget {
  final BookingRequest request;
  const _BookingFeeExplainer({required this.request});

  Widget _point(IconData icon, String title, String text) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textGrey)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final fee = request.fee;
    final total = request.serviceTotal;
    final balance = total - fee;
    final business = request.providerName;
    final percent = (kBookingFeeRate * 100).round();
    return GreyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Booking fee',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ),
              Text('R$fee',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.teal)),
            ],
          ),
          const SizedBox(height: 4),
          Text('$percent% of the R$total service price',
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
          _point(
            Icons.event_available_outlined,
            'Secures your time slot',
            'It reserves ${request.date} at ${request.time} with $business while they review your request.',
          ),
          _point(
            Icons.replay_rounded,
            'Refundable',
            'If $business declines your booking, the full R$fee is sent back to you. '
                'Still waiting for them to accept? You can cancel and get it all back.',
          ),
          _point(
            Icons.savings_outlined,
            'Counts toward the price',
            'It is not an extra charge. After the service you pay the remaining R$balance.',
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Text(
            'Once the business accepts, the booking fee becomes part of the price and is not refunded if you cancel.',
            style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}
