import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Saffron marks the one thing to do on each screen; ink carries the rest.
class AppColors {
  static const saffron = Color(0xFFE3620C);
  static const saffronDeep = Color(0xFFC24F06);
  static const saffronInk = Color(0xFFB84C04);
  static const saffronSoft = Color(0xFFFFEFE2);
  static const ink = Color(0xFF171A2E);
  static const inkSoft = Color(0xFF2A2E4A);
  static const muted = Color(0xFF5D6178);
  static const line = Color(0xFFE6E8EF);
  static const ground = Color(0xFFF1F2F5);
  static const surface = Color(0xFFFFFFFF);
  static const ok = Color(0xFF1C7F55);
  static const okSoft = Color(0xFFE3F4EC);
  static const warn = Color(0xFF9A6408);
  static const warnSoft = Color(0xFFFBF1DC);
  static const bad = Color(0xFFB8322A);
  static const badSoft = Color(0xFFFBE7E5);
  static const info = Color(0xFF2E55C9);
  static const infoSoft = Color(0xFFE6ECFB);
  static const verified = Color(0xFF1D7BE0);
}

/// Soft, layered shadow used on raised cards.
const softShadow = [
  BoxShadow(color: Color(0x0F171A2E), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(
    color: Color(0x14171A2E),
    blurRadius: 18,
    offset: Offset(0, 8),
    spreadRadius: -6,
  ),
];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.saffron,
    primary: AppColors.saffron,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
  );

  final field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.line),
  );
  const display = TextStyle(
    fontFamily: 'Anek',
    color: AppColors.ink,
    height: 1.15,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Mukta',
    scaffoldBackgroundColor: AppColors.ground,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Anek',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    textTheme: TextTheme(
      headlineMedium: display.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineSmall: display.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge: display.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        color: AppColors.ink,
        height: 1.45,
      ),
      bodyMedium: const TextStyle(
        fontSize: 15,
        color: AppColors.ink,
        height: 1.45,
      ),
      bodySmall: const TextStyle(
        fontSize: 13,
        color: AppColors.muted,
        height: 1.35,
      ),
      labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(
        borderSide: const BorderSide(color: AppColors.saffron, width: 1.6),
      ),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(
        color: AppColors.saffronInk,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'Mukta',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Mukta',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.saffronInk,
        textStyle: const TextStyle(
          fontFamily: 'Mukta',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyle(
        fontFamily: 'Mukta',
        fontSize: 15,
        color: AppColors.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'Mukta',
        fontSize: 13,
        color: AppColors.muted,
        height: 1.35,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(
        fontFamily: 'Mukta',
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.white : AppColors.ink,
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Mukta', fontWeight: FontWeight.w600),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      height: 72,
      elevation: 0,
      indicatorColor: AppColors.saffronSoft,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Mukta',
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.saffronInk
              : AppColors.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: const TextStyle(
        fontFamily: 'Mukta',
        color: Colors.white,
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}
