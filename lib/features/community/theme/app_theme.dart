import 'package:flutter/material.dart';

import '../../shared/brand.dart';

class AppColors {
  // Brand colours from the logo: navy + blue, with a red accent.
  // (`teal` is the old name for the main brand blue; kept so existing code works.)
  static const teal = Color(0xFF1F5FA8);
  static const primary = teal;
  /// Red accent for key calls to action (Book) and proof-of-service highlights.
  static const accent = Color(0xFFD62839);
  static const navy = Color(0xFF1B2F5E);
  static const text = Color(0xFF1F2937);
  static const textDark = text;
  static const muted = Color(0xFF6B7280);
  static const textGrey = muted;
  static const inputBg = Color(0xFFF3F4F6);
  static const greyBg = inputBg;
  static const border = Color(0xFFD1D5DB);
  /// Very light divider / card outline.
  static const hairline = Color(0xFFE5E7EB);
  /// Page background behind white cards.
  static const surface = Color(0xFFF9FAFB);
  static const borderGrey = border;
  static const green = Color(0xFF1FA24A);
  static const orange = Color(0xFFF5A623);
  static const red = Color(0xFFE5251F);
  static const avatarBg = Color(0xFFE6EEF8);
  static const avatarIcon = teal;
}

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.teal),
        scaffoldBackgroundColor: Colors.white,
        // Headings and buttons use Poppins; body text keeps the default font.
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontFamily: kHeadingFont, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontFamily: kHeadingFont, fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(fontFamily: kHeadingFont, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontFamily: kHeadingFont, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontFamily: kHeadingFont, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontFamily: kHeadingFont, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(fontFamily: kHeadingFont, fontWeight: FontWeight.w600),
        ),
        // Every page title looks the same: Poppins 18, left-aligned.
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.text,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleSpacing: 0,
          titleTextStyle: headingStyle(
              size: 18, weight: FontWeight.w600, color: AppColors.text),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppColors.muted,
          titleTextStyle: TextStyle(fontSize: 15, color: AppColors.text),
          subtitleTextStyle: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Colors.white : AppColors.muted),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? AppColors.teal : AppColors.hairline),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(0, 48),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.red, width: 1.2),
          ),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.teal,
          selectionHandleColor: AppColors.teal,
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: AppColors.teal),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          closeIconColor: Colors.white,
          backgroundColor: AppColors.text,
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.teal),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
          ),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.hairline, space: 1),
      );
}
