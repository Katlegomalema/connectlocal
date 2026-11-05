import 'package:connect_local/features/community/models/models.dart';
import 'package:connect_local/features/community/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same numbers as backend/tests/unit/moneyMath.test.js, so app and server agree to the cent.
void main() {
  test('15% fee exact to the cent, rounded half up like the backend', () {
    expect(bookingFeeFor(450), 67.5);
    expect(bookingFeeFor(333.33), 50.0); // 49.9995 -> 50.00
    expect(bookingFeeFor(199.95), 29.99); // 29.9925 -> 29.99
    expect(bookingFeeFor(1800), 270);
  });

  test('booking balance = price - fee', () {
    final b = Booking(
      id: 'b', providerId: 'p', serviceId: 's', serviceName: 'Fix', clientName: 'Pat',
      dateTime: DateTime(2026, 11, 6, 10), price: 450,
    );
    expect(b.bookingFee, 67.5);
    expect(b.balance, 382.5);
    expect(roundMoney(b.bookingFee + b.balance), 450);
  });

  test('money() shows cents only when there are any', () {
    expect(money(450), 'R450');
    expect(money(67.5), 'R67.50');
    expect(money(382.5), 'R382.50');
    expect(money(0.1 + 0.2), 'R0.30');
  });
}
