import 'dart:async';

import 'package:flutter/material.dart';

import 'busy_button.dart';

/// Colours sampled from the Figma designs.
class FigmaColors {
  FigmaColors._();
  static const teal = Color(0xFF1F5FA8); // brand blue (old name)
  static const title = Color(0xFF111827);
  static const body = Color(0xFF6B7280);
  static const border = Color(0xFFD1D5DB);
  static const error = Color(0xFFE5251F);
}

OutlineInputBorder _border(Color color, [double width = 1]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color, width: width),
  );
}

/// Outlined, white, rounded text-field style used on every Figma form.
InputDecoration figmaInput(String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: FigmaColors.body, fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: _border(FigmaColors.border),
    enabledBorder: _border(FigmaColors.border),
    focusedBorder: _border(FigmaColors.teal, 1.5),
    errorBorder: _border(FigmaColors.error),
    focusedErrorBorder: _border(FigmaColors.error, 1.5),
  );
}

/// Takes the user back to the first screen of the stack (normally Login when
/// the flow was opened from Login, or Home when opened from Home/Profile).
void popToRoot(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// White page with the teal "<" back chevron from the Figma designs.
class FigmaPage extends StatelessWidget {
  final Widget child;
  final Widget? bottom;
  final bool showBack;

  const FigmaPage({
    super.key,
    required this.child,
    this.bottom,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottomWidget = bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: showBack
                    ? IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.chevron_left,
                          size: 34,
                          color: FigmaColors.teal,
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: child,
              ),
            ),
            if (bottomWidget != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: bottomWidget,
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-width teal button.
class FigmaButton extends StatelessWidget {
  final String label;
  final FutureOr<void> Function() onPressed;

  const FigmaButton(this.label, {super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: BusyElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: FigmaColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// "Remember your password? **Login**" style line (link part is tappable).
class FigmaLinkLine extends StatelessWidget {
  final String prefix;
  final String link;
  final VoidCallback onTap;
  final bool underline;

  const FigmaLinkLine({
    super.key,
    this.prefix = '',
    required this.link,
    required this.onTap,
    this.underline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (prefix.isNotEmpty)
          Text(
            '$prefix ',
            style: const TextStyle(fontSize: 15, color: FigmaColors.body),
          ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            link,
            style: TextStyle(
              fontSize: 15,
              fontWeight: underline ? FontWeight.w400 : FontWeight.w700,
              color: FigmaColors.teal,
              decoration:
                  underline ? TextDecoration.underline : TextDecoration.none,
              decorationColor: FigmaColors.teal,
            ),
          ),
        ),
      ],
    );
  }
}
