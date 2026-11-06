import 'dart:async';

import 'package:flutter/material.dart';

/// An [ElevatedButton] that, when [onPressed] returns a Future (e.g. `() => app.saveService(...)`),
/// shows a spinner and ignores further taps until that Future finishes. So a request can never be sent twice
/// by tapping again while it is running.
class BusyElevatedButton extends StatefulWidget {
  final FutureOr<void> Function()? onPressed;
  final ButtonStyle? style;
  final Widget child;

  /// Show the spinner even when not started from this button (the screen is already working).
  final bool loading;
  final Color spinnerColor;

  const BusyElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.loading = false,
    this.spinnerColor = Colors.white,
  });

  @override
  State<BusyElevatedButton> createState() => _BusyElevatedButtonState();
}

class _BusyElevatedButtonState extends State<BusyElevatedButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    final result = widget.onPressed?.call();
    if (result is! Future) return;
    setState(() => _busy = true);
    try {
      await result;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final working = _busy || widget.loading;
    return ElevatedButton(
      onPressed: widget.onPressed == null || working ? null : _tap,
      style: widget.style,
      child: working
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: widget.spinnerColor),
            )
          : widget.child,
    );
  }
}
