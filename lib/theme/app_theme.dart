import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 앱 전체 다크 테마 — 아침 알람 스타일 (검은 바탕, 흰 글씨)
class AppTheme {
  AppTheme._();

  static const bg = Color(0xFF1A1814);
  static const surface = Color(0xFF2A2520);
  static const surfaceLight = Color(0xFF3A3530);
  static const text = Colors.white;
  static const textMuted = Color(0xFF9A9088);
  static const accent = Color(0xFFC9952F);
  static const done = Color(0xFF6B8F5E);
  static const like = Color(0xFF993556);
  static const off = Color(0xFF993556);

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: bg,
        surface: surface,
        onSurface: text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        iconTheme: IconThemeData(color: textMuted),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: textMuted),
        titleLarge: TextStyle(color: text, fontFamily: 'serif'),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceLight),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.4);
          }
          return surfaceLight;
        }),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: text),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: surface),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData timePickerTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: bg,
        surface: surface,
        onSurface: text,
      ),
    );
  }
}
