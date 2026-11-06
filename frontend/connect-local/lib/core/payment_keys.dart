import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// One Idempotency-Key per booking and payment kind (booking fee / balance), kept on the device until that
/// payment is paid. Every "start payment" for it sends the same key, also after the app was closed, so the
/// server always answers with the same payment and the customer is never charged twice.
class PaymentKeys {
  PaymentKeys._();

  static String _name(String bookingId, String purpose) => 'cl_payment_key_${bookingId}_$purpose';

  static Future<String> keyFor(String bookingId, String purpose) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_name(bookingId, purpose));
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final key = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(_name(bookingId, purpose), key);
    return key;
  }

  /// The payment is paid: the key is not needed any more.
  static Future<void> forget(String bookingId, String purpose) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_name(bookingId, purpose));
  }
}
