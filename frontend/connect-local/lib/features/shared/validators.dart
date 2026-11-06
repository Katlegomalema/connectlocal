import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'verification.dart';

/// Input rules for every form: the SAME rules and messages as the backend (backend/src/utils/validators.js).
/// Each returns null when the value is fine, otherwise the message to show under the field.
/// The backend checks again; it is the final word.
class Validators {
  Validators._();

  static final _htmlOrScript = RegExp(r'<\s*/?\s*[a-z!?]|javascript\s*:|\bon[a-z]+\s*=', caseSensitive: false);
  static final _personName = RegExp(r"^\p{L}+(?:[ '’-]\p{L}+)*$", unicode: true);
  static final _hasLetter = RegExp(r'\p{L}', unicode: true);

  static String oneLine(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Letters (accents too), spaces, hyphens and apostrophes; 2-100. "Thabo Mokoena", "Anne-Marie", "O'Neil".
  static String? personName(String? value) {
    final v = oneLine(value ?? '');
    if (v.length < 2) return 'Name needs at least 2 letters';
    if (v.length > 100) return 'Name can have at most 100 characters';
    if (!_personName.hasMatch(v)) return "Use letters only (spaces, - and ' are fine), no digits or symbols";
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your email address';
    if (v.length > 254 || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  /// +27 82 123 4567 / 082 123 4567 -> "+27821234567", or null when it is not a South African number.
  static String? normaliseSaPhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[\s()-]'), '');
    if (RegExp(r'^0[1-8]\d{8}$').hasMatch(digits)) return '+27${digits.substring(1)}';
    if (RegExp(r'^27[1-8]\d{8}$').hasMatch(digits)) return '+$digits';
    if (RegExp(r'^\+27[1-8]\d{8}$').hasMatch(digits)) return digits;
    return null;
  }

  static String? saPhone(String? value) => normaliseSaPhone(value) == null
      ? 'Enter a South African number, e.g. 082 123 4567 or +27 82 123 4567'
      : null;

  /// At least 8 characters with a capital letter, a small letter and a number.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (v.length > 72) return 'Password can have at most 72 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Password must contain a capital letter';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Password must contain a small letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Password must contain a number';
    return null;
  }

  static String? saId(String? value) =>
      parseSaId(value ?? '') == null ? 'That South African ID number is not valid' : null;

  static String? registrationNumber(String? value) => checkRegistrationNumber(value ?? '');

  static String? businessName(String? value) {
    final v = oneLine(value ?? '');
    if (v.length < 2 || v.length > 150) return 'Business name needs 2 to 150 characters';
    if (!isValidBusinessName(v)) return "Use letters, digits, spaces and & . , ' ( ) - only";
    return null;
  }

  static String? bankAccount(String? value) => checkBankAccountNumber(value ?? '');
  static String? branchCode(String? value) => checkBranchCode(value ?? '');

  /// More than R0, at most R1 000 000, at most 2 decimals ("350", "349.99").
  static String? price(String? value) {
    final v = (value ?? '').trim().replaceAll(' ', '').replaceAll(',', '.');
    if (v.isEmpty) return 'Enter a price, e.g. 350 or 349.99';
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v)) {
      return RegExp(r'^\d+\.\d{3,}$').hasMatch(v) ? 'Use at most 2 decimals (cents)' : 'Enter a price, e.g. 350 or 349.99';
    }
    final amount = double.parse(v);
    if (amount <= 0) return 'The price must be more than R0';
    if (amount > 1000000) return 'The price can be at most R1 000 000';
    return null;
  }

  static String? futureDateTime(DateTime? value) {
    if (value == null) return 'Choose a date and time';
    if (value.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) return 'That date and time is in the past';
    return null;
  }

  static String? address(String? value) {
    final v = oneLine(value ?? '');
    if (v.length < 5 || !_hasLetter.hasMatch(v)) return 'Enter the full address (street, suburb, city)';
    if (v.length > 300) return 'The address can have at most 300 characters';
    if (_htmlOrScript.hasMatch(v)) return 'The address cannot contain HTML or code';
    return null;
  }

  /// Free text with a length limit and no HTML/script, e.g. `Validators.text(v, max: 500, label: 'Your review')`.
  static String? text(String? value, {required int max, int min = 0, String label = 'This field'}) {
    final v = (value ?? '').trim();
    if (v.length < min) return min > 0 ? '$label needs at least $min characters' : '$label is required';
    if (v.length > max) return '$label can have at most $max characters';
    if (_htmlOrScript.hasMatch(v)) return '$label cannot contain HTML or code';
    return null;
  }

  static String? required(String? value, String message) => (value ?? '').trim().isEmpty ? message : null;
}

/// Types "2019/123456/07" for the person: digits only, the slashes are added automatically
/// (a number keyboard on Android has no "/" key).
class RegistrationNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 12 ? digits.substring(0, 12) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 4 || i == 10) buffer.write('/');
      buffer.write(clipped[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// A text field that shows its problem under itself once the person has left it, and from then on
/// updates as they type (not only when they press Submit).
class ValidatedField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?) validator;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int? minLines;
  final int maxLines;
  final int? maxLength;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final TextStyle? style;
  final bool enabled;
  final Iterable<String>? autofillHints;

  const ValidatedField({
    super.key,
    required this.controller,
    required this.validator,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.onChanged,
    this.focusNode,
    this.style,
    this.enabled = true,
    this.autofillHints,
  });

  @override
  State<ValidatedField> createState() => _ValidatedFieldState();
}

class _ValidatedFieldState extends State<ValidatedField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!_focus.hasFocus && !_touched && mounted) setState(() => _touched = true);
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        validator: widget.validator,
        autovalidateMode: _touched ? AutovalidateMode.always : AutovalidateMode.disabled,
        decoration: widget.decoration.copyWith(errorMaxLines: 3),
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        textCapitalization: widget.textCapitalization,
        minLines: widget.minLines,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        maxLength: widget.maxLength,
        obscureText: widget.obscureText,
        onChanged: widget.onChanged,
        style: widget.style,
        enabled: widget.enabled,
        autofillHints: widget.autofillHints,
      );
}

/// Checks every field of the form. When something is wrong, scrolls to the FIRST wrong field so the person
/// sees why nothing happened (an error far up the page looked like "the button does nothing").
bool validateAndReveal(GlobalKey<FormState> formKey) {
  final form = formKey.currentState;
  if (form == null || form.validate()) return true;
  FormFieldState<dynamic>? first;
  void visit(Element element) {
    if (first != null) return;
    if (element is StatefulElement && element.state is FormFieldState && (element.state as FormFieldState).hasError) {
      first = element.state as FormFieldState;
      return;
    }
    element.visitChildren(visit);
  }

  formKey.currentContext?.visitChildElements(visit);
  final target = first;
  if (target != null) {
    Scrollable.ensureVisible(target.context, duration: const Duration(milliseconds: 300), alignment: 0.2);
  }
  return false;
}
