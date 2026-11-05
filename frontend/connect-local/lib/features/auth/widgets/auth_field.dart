import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rounded text box used on the Login and Register screens.
/// Set isPassword: true to get the show/hide eye icon.
class AuthField extends StatefulWidget {
  final String hint;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final bool showEye;
  final IconData? icon;
  final FocusNode? focusNode;

  /// Shown in red under the box (e.g. "Password must be at least 8 characters").
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const AuthField({
    super.key,
    required this.hint,
    required this.controller,
    this.isPassword = false,
    this.showEye = true,
    this.icon,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      obscureText: widget.isPassword && _hidden,
      onChanged: widget.onChanged,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textGrey),
        errorText: widget.errorText,
        errorMaxLines: 3,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        prefixIcon: widget.icon == null
            ? null
            : Icon(widget.icon, size: 20, color: AppColors.textGrey),
        suffixIcon: widget.isPassword && widget.showEye
            ? IconButton(
          icon: Icon(
            _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: AppColors.textGrey,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
        )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.teal),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}