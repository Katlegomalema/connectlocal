import 'package:flutter/material.dart';

/// Poppins (bundled in assets/fonts) is the app's heading font.
const String kHeadingFont = 'Poppins';

/// Heading text style. Same navy as before; only the typeface is new.
TextStyle headingStyle({
  double size = 20,
  FontWeight weight = FontWeight.w700,
  Color color = const Color(0xFF1B2F5E),
  double? height,
}) =>
    TextStyle(
      fontFamily: kHeadingFont,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
