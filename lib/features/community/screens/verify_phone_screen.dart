import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/verification.dart';
import 'package:flutter/services.dart';

import '../../shared/brand.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Verify Phone: enter number -> enter 6-digit code -> verified.
///
/// TODO (backend): until an SMS service is connected, [_sendCode] only moves to
/// the next step and [_verify] accepts any 6 digits. Replace those two calls
/// with the real "send code" / "check code" requests.
class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

enum _Step { phone, code, done }

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  static const _codeLength = 6;
  static const _resendSeconds = 30;

  final _phone = TextEditingController();
  final _phoneFocus = FocusNode();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();

  _Step _step = _Step.phone;
  bool _busy = false;
  String? _error;
  int _secondsLeft = 0;
  Timer? _timer;
  bool _checkedExisting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-opening the screen after a number was verified shows the result.
    if (!_checkedExisting) {
      _checkedExisting = true;
      if (AppScope.of(context).verifiedPhone != null) _step = _Step.done;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _phoneFocus.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  /// South African mobile numbers are 9 digits after +27 (e.g. 82 123 4567).
  String get _digits {
    final d = _phone.text.replaceAll(RegExp(r'\D'), '');
    // People often type the leading 0 (082 123 4567); +27 replaces it.
    return d.startsWith('0') ? d.substring(1) : d;
  }
  bool get _phoneValid => _digits.length == 9;
  String get _formattedPhone {
    final d = _digits;
    if (d.length != 9) return '+27 $d';
    return '+27 ${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5)}';
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_busy) return;
    if (!_phoneValid) {
      setState(() => _error = 'Enter a valid 9-digit mobile number.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    // No SMS provider yet: the code is really generated and checked, and the
    // "SMS" is shown on screen. TODO (backend): send it by SMS instead.
    final code = OtpService.instance.send(_formattedPhone);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 30),
      showCloseIcon: true,
      content: Text('Demo SMS to $_formattedPhone: your ConnectLocal code is $code'),
    ));
    _code.clear();
    setState(() {
      _busy = false;
      _step = _Step.code;
    });
    _startTimer();
    if (resend) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(duration: const Duration(seconds: 3), content: Text('A new code has been sent.')));
    }
    _codeFocus.requestFocus();
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_code.text.length != _codeLength) {
      setState(() => _error = 'Enter the 6-digit code we sent you.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final result = OtpService.instance.check(_formattedPhone, _code.text);
    if (result != OtpCheck.ok) {
      setState(() {
        _busy = false;
        _code.clear();
        _error = switch (result) {
          OtpCheck.wrong =>
            'Wrong code. ${OtpService.instance.triesLeft} tries left.',
          OtpCheck.expired => 'That code has expired. Tap Resend for a new one.',
          OtpCheck.tooManyTries =>
            'Too many wrong tries. Tap Resend for a new code.',
          _ => 'Request a code first.',
        };
      });
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    AppScope.read(context).setVerifiedPhone(_formattedPhone);
    _timer?.cancel();
    setState(() {
      _busy = false;
      _step = _Step.done;
    });
  }

  void _changeNumber() {
    _timer?.cancel();
    _code.clear();
    setState(() {
      _step = _Step.phone;
      _error = null;
    });
    _phoneFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 24),
                child: switch (_step) {
                  _Step.phone => _phoneStep(),
                  _Step.code => _codeStep(),
                  _Step.done => _doneStep(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- shared pieces -------------------------------------------------------

  Widget _badge(IconData icon, {Color color = AppColors.teal}) => Center(
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 40, color: color),
        ),
      );

  Widget _heading(String title, Widget subtitle) => Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: headingStyle(size: 24, color: AppColors.text)),
          const SizedBox(height: 10),
          DefaultTextStyle(
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.45, color: AppColors.muted),
            child: subtitle,
          ),
        ],
      );

  Widget _errorText() => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.red),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_error!,
                  style: const TextStyle(fontSize: 13, color: AppColors.red)),
            ),
          ],
        ),
      );

  // ---- step 1: phone number -----------------------------------------------

  Widget _phoneStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _badge(Icons.smartphone_rounded),
          const SizedBox(height: 28),
          _heading(
            'Verify your phone',
            const Text('Enter your mobile number to receive a verification code.'),
          ),
          const SizedBox(height: 32),
          const Text('Mobile number',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: const Text('+27',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phone,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _sendCode(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                    LengthLimitingTextInputFormatter(12),
                  ],
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '82 123 4567',
                    hintStyle: const TextStyle(fontSize: 15, color: AppColors.muted),
                    filled: false,
                    prefixIcon:
                        const Icon(Icons.phone_outlined, size: 20, color: AppColors.muted),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: _error != null ? AppColors.red : AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: _error != null ? AppColors.red : AppColors.teal,
                          width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) _errorText(),
          const SizedBox(height: 28),
          PrimaryButton('Send code', loading: _busy, onPressed: _sendCode),
          const SizedBox(height: 18),
          const Text(
            'We’ll text you a 6-digit code to confirm your number. '
            'Standard message rates may apply.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
          ),
        ],
      );

  // ---- step 2: code ----------------------------------------------------------

  Widget _codeStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _badge(Icons.sms_outlined),
          const SizedBox(height: 28),
          _heading(
            'Enter verification code',
            Column(
              children: [
                const Text('We’ve sent a 6-digit code to'),
                const SizedBox(height: 2),
                Text(_formattedPhone,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.text)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _OtpBoxes(
            controller: _code,
            focusNode: _codeFocus,
            length: _codeLength,
            hasError: _error != null,
            onChanged: () => setState(() => _error = null),
            onCompleted: _verify,
          ),
          if (_error != null) _errorText(),
          const SizedBox(height: 28),
          PrimaryButton('Verify', loading: _busy, onPressed: _verify),
          const SizedBox(height: 16),
          Center(
            child: _secondsLeft > 0
                ? Text(
                    'Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 14, color: AppColors.muted),
                  )
                : TextButton(
                    onPressed: _busy ? null : () => _sendCode(resend: true),
                    child: const Text('Resend code',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
          ),
          Center(
            child: TextButton(
              onPressed: _changeNumber,
              child: const Text('Change number',
                  style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ),
          ),
        ],
      );

  // ---- step 3: verified ------------------------------------------------------

  Widget _doneStep() {
    final number = AppScope.of(context).verifiedPhone ?? _formattedPhone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        _badge(Icons.check_circle_rounded, color: AppColors.green),
        const SizedBox(height: 28),
        _heading(
          'Phone verified',
          Column(
            children: [
              const Text('Your number is confirmed:'),
              const SizedBox(height: 2),
              Text(number,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.text)),
            ],
          ),
        ),
        const SizedBox(height: 36),
        PrimaryButton('Done', onPressed: () => Navigator.maybePop(context)),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () {
              _phone.clear();
              _changeNumber();
            },
            child: const Text('Use a different number',
                style: TextStyle(fontSize: 14, color: AppColors.muted)),
          ),
        ),
      ],
    );
  }
}

/// Six digit boxes backed by one invisible text field, so typing, deleting,
/// pasting and SMS autofill all just work.
class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;
  final VoidCallback onChanged;
  final VoidCallback onCompleted;

  const _OtpBoxes({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.hasError,
    required this.onChanged,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focusNode.requestFocus,
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final text = controller.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < length; i++)
                    _box(
                      char: i < text.length ? text[i] : '',
                      active: focusNode.hasFocus &&
                          (i == text.length || (i == length - 1 && text.length == length)),
                    ),
                ],
              );
            },
          ),
          // The real input: invisible, but it receives focus, typing and paste.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(length),
                ],
                onChanged: (value) {
                  onChanged();
                  if (value.length == length) onCompleted();
                },
                decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box({required String char, required bool active}) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 46,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: char.isEmpty ? Colors.white : AppColors.teal.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasError
                ? AppColors.red
                : active
                    ? AppColors.teal
                    : AppColors.border,
            width: active || hasError ? 1.6 : 1,
          ),
        ),
        child: Text(
          char,
          style: headingStyle(size: 22, color: AppColors.text),
        ),
      );
}
