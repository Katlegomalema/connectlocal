import 'dart:convert';

import 'package:connect_local/core/api_client.dart';
import 'package:connect_local/core/connect_local_repository.dart';
import 'package:connect_local/core/payment_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('"start payment" sends the same Idempotency-Key every time for a booking + kind', () async {
    final keys = <String>[];
    var calls = 0;
    final repo = ConnectLocalRepository(ApiClient(
      baseUrl: 'https://example.test',
      retryDelay: (_) => Duration.zero,
      httpClient: MockClient((request) async {
        calls++;
        keys.add(request.headers['Idempotency-Key'] ?? '-');
        if (calls == 2) throw http.ClientException('Connection reset'); // slow / broken network on the 2nd try
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {'paymentId': 'payment-1', 'checkoutUrl': 'https://x/checkout', 'amount': 67.5, 'status': 'pending'}
            }),
            calls == 1 ? 201 : 200,
            headers: {'content-type': 'application/json'});
      }),
    ));

    final first = await repo.startPayment('booking-1', 'booking_fee');
    await expectLater(repo.startPayment('booking-1', 'booking_fee'), throwsA(isA<ApiException>()));
    final third = await repo.startPayment('booking-1', 'booking_fee'); // "Try again"
    await repo.startPayment('booking-1', 'balance');
    await repo.startPayment('booking-2', 'booking_fee');

    expect(calls, 5, reason: 'a POST is never retried automatically');
    expect(keys[0], 'bk-booking-1-booking_fee');
    expect(keys.sublist(0, 3).toSet(), hasLength(1), reason: 'same key for every try of the same payment');
    expect(keys[3], isNot(keys[0]), reason: 'the balance is another payment');
    expect(keys[4], isNot(keys[0]), reason: 'another booking');
    expect(third.paymentId, first.paymentId);
  });

  test('the key is the same on every device and after the app was closed (nothing stored)', () async {
    expect(await PaymentKeys.keyFor('booking-1', 'booking_fee'), await PaymentKeys.keyFor('booking-1', 'booking_fee'));
    expect(await PaymentKeys.keyFor('booking-1', 'booking_fee'), isNot(await PaymentKeys.keyFor('booking-1', 'balance')));
    expect(RegExp(r'^[A-Za-z0-9_-]{8,100}$').hasMatch(await PaymentKeys.keyFor('6f1c0f3e-1d2b-4c5a-9e8f-0a1b2c3d4e5f', 'booking_fee')),
        isTrue, reason: 'the server accepts letters, digits, - and _ (8-100)');
  });

  test('an already-paid answer is reported as paid (no checkout to open)', () async {
    final repo = ConnectLocalRepository(ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {'paymentId': 'payment-1', 'checkoutUrl': null, 'amount': 67.5, 'status': 'paid', 'alreadyPaid': true}
          }),
          200,
          headers: {'content-type': 'application/json'})),
    ));
    final result = await repo.startPayment('booking-1', 'booking_fee');
    expect(result.alreadyPaid, isTrue);
    expect(result.checkoutUrl, isNull);
  });
}
