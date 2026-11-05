/// Card payments go through PayFast (https://www.payfast.co.za).
///
/// The app NEVER sees card numbers: PayFast's hosted page collects them. The
/// app asks the backend for a checkout link, opens it, and then waits for the
/// backend to confirm the payment (PayFast tells the backend directly through
/// its "ITN" notification, so a customer can't fake a successful payment).
///
/// TODO (backend): see FRONTEND_HANDOVER.md, "PayFast", for exactly what the
/// backend must do. Until then [DemoPayFastService] simulates a successful
/// payment so the whole flow can be tested.
class PaymentRequest {
  /// Our own unique payment id (PayFast field `m_payment_id`).
  final String reference;
  final int amountRand;
  final String itemName;
  final String customerName;
  final String customerEmail;

  /// Which PayFast method the customer picked: 'cc' card, 'eft' instant EFT,
  /// 'apple' Apple Pay, 'sp' Samsung Pay, 'cp' Capitec Pay, 'mp' Scan to Pay
  /// (SnapScan / Zapper / Masterpass), 'mc' Mobicred. TODO (backend): map to PayFast's payment_method field.
  final String method;

  const PaymentRequest({
    required this.reference,
    required this.amountRand,
    required this.itemName,
    required this.customerName,
    required this.customerEmail,
    this.method = 'cc',
  });
}

class PaymentResult {
  final bool success;

  /// PayFast's payment id (`pf_payment_id`) when [success].
  final String? gatewayReference;
  final String? message;

  const PaymentResult.success(this.gatewayReference)
      : success = true,
        message = null;

  const PaymentResult.failed([this.message])
      : success = false,
        gatewayReference = null;
}

abstract class PaymentService {
  Future<PaymentResult> payWithCard(PaymentRequest request);
}

/// Simulates the PayFast hosted page. Replace with the real service.
class DemoPayFastService implements PaymentService {
  const DemoPayFastService();

  @override
  Future<PaymentResult> payWithCard(PaymentRequest request) async {
    await Future<void>.delayed(const Duration(seconds: 3));
    return PaymentResult.success('PF-${DateTime.now().millisecondsSinceEpoch}');
  }
}

/// The service the app uses. Change this one line when the real one exists.
PaymentService paymentService = const DemoPayFastService();
