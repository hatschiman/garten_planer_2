import 'package:flutter/material.dart';

/// Ruhiges Waldgrün als Primärfarbe, warme helle Hintergrundflächen.
const Color kForestGreen = Color(0xFF2F5E3F);
const Color kWarmSurface = Color(0xFFFAF7F0);
const Color kWarmSurfaceLow = Color(0xFFF2EDE2);

ThemeData buildGartenTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: kForestGreen,
        brightness: Brightness.light,
      ).copyWith(
        primary: kForestGreen,
        surface: kWarmSurface,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: kWarmSurfaceLow,
        surfaceContainer: const Color(0xFFEDE7DA),
        surfaceContainerHigh: const Color(0xFFE7E0D2),
        surfaceContainerHighest: const Color(0xFFE0D9CA),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kWarmSurface,
    appBarTheme: AppBarTheme(
      backgroundColor: kWarmSurface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
      fillColor: Colors.white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kWarmSurface,
      showDragHandle: true,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Formatiert Meter mit deutschem Dezimaltrennzeichen.
String fmtMeters(double v, {int decimals = 1}) =>
    '${v.toStringAsFixed(decimals).replaceAll('.', ',')} m';
