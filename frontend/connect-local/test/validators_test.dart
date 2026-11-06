import 'package:connect_local/features/shared/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same examples as backend/tests/unit/validators.test.js: both sides must agree.
void main() {
  test('names: letters incl. accents, spaces, hyphens, apostrophes; 2-100; no digits/symbols', () {
    for (final name in ['Thabo Mokoena', 'Anne-Marie', "O'Neil", 'Zoë Ndlovu', ' Nomsa  Khumalo ', 'José', 'Jo']) {
      expect(Validators.personName(name), isNull, reason: name);
    }
    expect(Validators.personName('Thabo2'), contains('letters only'));
    expect(Validators.personName('Thabo!'), contains('letters only'));
    expect(Validators.personName('-Anne'), contains('letters only'));
    expect(Validators.personName('A'), contains('at least 2'));
    expect(Validators.personName('a' * 101), contains('at most 100'));
  });

  test('email', () {
    expect(Validators.email(' Pat@Example.CO.ZA '), isNull);
    expect(Validators.email('pat@example'), contains('valid email'));
    expect(Validators.email(''), contains('Enter'));
  });

  test('SA phone numbers', () {
    expect(Validators.normaliseSaPhone('082 123 4567'), '+27821234567');
    expect(Validators.normaliseSaPhone('+27 82 123 4567'), '+27821234567');
    expect(Validators.normaliseSaPhone('011-555-1234'), '+27115551234');
    expect(Validators.saPhone('0021234567'), contains('South African number'));
    expect(Validators.saPhone('+44 20 7946 0000'), contains('South African number'));
  });

  test('passwords: 8+, capital, small letter, number', () {
    expect(Validators.password('Longpass1'), isNull);
    expect(Validators.password('Short1a'), contains('at least 8'));
    expect(Validators.password('longpass1'), contains('capital'));
    expect(Validators.password('LONGPASS1'), contains('small letter'));
    expect(Validators.password('Longpasss'), contains('number'));
  });

  test('SA ID number and registration number', () {
    expect(Validators.saId('9001015009086'), isNull);
    expect(Validators.saId('9001015009087'), contains('not valid'));
    expect(Validators.saId('9002305009083'), contains('not valid')); // 30 February
    expect(Validators.registrationNumber('2019/123456/07'), isNull);
    expect(Validators.registrationNumber('2019-123456-07'), contains('2019/123456/07'));
    expect(Validators.registrationNumber('2019/123456/99'), contains('company type'));
  });

  test('bank account, branch code, prices', () {
    expect(Validators.bankAccount('620 1234 5678'), isNull);
    expect(Validators.bankAccount('12345678'), contains('9 to 11'));
    expect(Validators.branchCode('25065'), contains('6 digits'));
    expect(Validators.price('349.99'), isNull);
    expect(Validators.price('450'), isNull);
    expect(Validators.price('0'), contains('more than R0'));
    expect(Validators.price('10.555'), contains('2 decimals'));
    expect(Validators.price('abc'), isNotNull);
  });

  test('dates, addresses, free text', () {
    expect(Validators.futureDateTime(DateTime.now().add(const Duration(hours: 1))), isNull);
    expect(Validators.futureDateTime(DateTime(2020)), contains('in the past'));
    expect(Validators.address('12 Church Street, Pretoria'), isNull);
    expect(Validators.address('12'), contains('full address'));
    expect(Validators.address('<b>12 Church St</b>'), contains('HTML'));
    expect(Validators.text('Great work, on time & tidy (5/5)!', max: 500, label: 'Your review'), isNull);
    expect(Validators.text('<script>alert(1)</script>', max: 500, label: 'Your review'), contains('HTML'));
    expect(Validators.text('<img src=x onerror=alert(1)>', max: 500), contains('HTML'));
    expect(Validators.text('x' * 501, max: 500, label: 'Your review'), contains('at most 500'));
  });

  test('business names', () {
    expect(Validators.businessName("Pat's Plumbing (Pty) Ltd"), isNull);
    expect(Validators.businessName('1234'), isNotNull);
    expect(Validators.businessName('Best <Plumbers>'), isNotNull);
  });

  test('registration number: the person types digits, the slashes are added', () {
    final formatter = RegistrationNumberFormatter();
    TextEditingValue type(String text) =>
        formatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));
    expect(type('201912345607').text, '2019/123456/07');
    expect(type('2019').text, '2019');
    expect(type('20191').text, '2019/1');
    expect(type('2019/123456/07').text, '2019/123456/07');
    expect(type('2019123456071234').text, '2019/123456/07', reason: 'extra digits are ignored');
  });

  testWidgets('a field shows its error once the person leaves it, then live while typing', (tester) async {
    final name = TextEditingController();
    final other = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          ValidatedField(controller: name, validator: Validators.personName),
          TextField(controller: other),
        ]),
      ),
    ));
    await tester.enterText(find.byType(TextFormField), 'Thabo2');
    await tester.pump();
    expect(find.textContaining('letters only'), findsNothing, reason: 'not while still typing the first time');

    await tester.tap(find.byType(TextField).last); // leave the field
    await tester.pump();
    expect(find.textContaining('letters only'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Thabo');
    await tester.pump();
    expect(find.textContaining('letters only'), findsNothing, reason: 'fixed: the error goes away as they type');
  });

  testWidgets('Submit scrolls to the first wrong field (no more "the button does nothing")', (tester) async {
    final formKey = GlobalKey<FormState>();
    final first = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          // Like the real forms: a scroll view whose fields all stay built.
          child: SingleChildScrollView(
            child: Column(children: [
              ValidatedField(controller: first, validator: Validators.personName),
              const SizedBox(height: 3000),
              ElevatedButton(onPressed: () => validateAndReveal(formKey), child: const Text('Submit')),
            ]),
          ),
        ),
      ),
    ));
    await tester.scrollUntilVisible(find.text('Submit'), 500, scrollable: find.byType(Scrollable).first);
    expect(tester.getTopLeft(find.byType(TextFormField)).dy, lessThan(0), reason: 'the field is off-screen');
    expect(find.textContaining('at least 2'), findsNothing);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('at least 2'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(TextFormField)).dy, greaterThanOrEqualTo(0), reason: 'scrolled back up');
  });
}
