/// The Idempotency-Key for "start payment": derived from the booking and the payment kind (booking fee /
/// balance), so every try, on every device, after the app was closed, sends the same key and the server
/// answers with the same payment. Nothing is stored on the device (CLAUDE.md: only sign-in tokens are).
class PaymentKeys {
  PaymentKeys._();

  static Future<String> keyFor(String bookingId, String purpose) async => 'bk-$bookingId-$purpose';

  /// Kept for the callers; nothing to forget because nothing is stored.
  static Future<void> forget(String bookingId, String purpose) async {}
}
