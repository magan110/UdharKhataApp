import 'package:flutter/material.dart';

abstract final class AppTokens {
  static const primary = Color(0xFF14532D);
  static const tint = Color(0xFFEAF4ED);
  static const canvas = Colors.white;
  static const muted = Color(0xFFF8FAF9);
  static const text = Color(0xFF111827);
  static const secondary = Color(0xFF475569);
  static const outline = Color(0xFF64748B);
  static const divider = Color(0xFFE2E8E4);
  static const credit = Color(0xFF9A3412);
  static const payment = Color(0xFF166534);
  static const pending = Color(0xFF92400E);
  static const pendingSurface = Color(0xFFFFF4D6);
  static const attention = Color(0xFFB91C1C);
  static const attentionSurface = Color(0xFFFEF2F2);
  static const radius = 16.0;
}

ThemeData clearCounterTheme() {
  final base = ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: AppTokens.primary, primary: AppTokens.primary, surface: Colors.white));
  return base.copyWith(
    scaffoldBackgroundColor: Colors.white,
    textTheme: base.textTheme.copyWith(
      headlineSmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTokens.text),
      titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTokens.text),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTokens.text),
      bodyLarge: const TextStyle(fontSize: 16, color: AppTokens.text),
      bodyMedium: const TextStyle(fontSize: 16, color: AppTokens.text),
      bodySmall: const TextStyle(fontSize: 14, color: AppTokens.secondary),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: AppTokens.text, surfaceTintColor: Colors.transparent, centerTitle: false),
    cardTheme: CardThemeData(color: AppTokens.muted, elevation: 0, margin: const EdgeInsets.symmetric(vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 56), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 56))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.all(16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTokens.outline))),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: AppTokens.tint),
    dividerTheme: const DividerThemeData(color: AppTokens.divider),
  );
}
