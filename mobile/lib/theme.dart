import 'package:flutter/material.dart';

/// Saffron marks the one thing to do on each screen; ink carries the rest.
class AppColors {
  static const saffron = Color(0xFFE3620C);
  static const saffronInk = Color(0xFFB84C04);
  static const saffronSoft = Color(0xFFFFEFE2);
  static const ink = Color(0xFF171A2E);
  static const muted = Color(0xFF5D6178);
  static const line = Color(0xFFE1E3EB);
  static const ground = Color(0xFFF3F4F7);
  static const surface = Color(0xFFFFFFFF);
  static const ok = Color(0xFF1C7F55);
  static const okSoft = Color(0xFFE3F4EC);
  static const warn = Color(0xFF9A6408);
  static const warnSoft = Color(0xFFFBF1DC);
  static const bad = Color(0xFFB8322A);
  static const badSoft = Color(0xFFFBE7E5);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.saffron,
    primary: AppColors.saffron,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
  );

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.line),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
      bodyMedium: TextStyle(fontSize: 15, color: AppColors.ink, height: 1.4),
      bodySmall: TextStyle(fontSize: 13, color: AppColors.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.saffron, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.saffronSoft,
    ),
  );
}
