import 'package:flutter/material.dart';

/// Runs a server action that returns an error message (or null) and shows the error, if any.
/// Returns true when it worked.
Future<bool> runAction(BuildContext context, Future<String?> action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await action;
  final text = error ?? success;
  if (text != null) {
    messenger.showSnackBar(SnackBar(duration: Duration(seconds: error == null ? 3 : 4), content: Text(text)));
  }
  return error == null;
}
