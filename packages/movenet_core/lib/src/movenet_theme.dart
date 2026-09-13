import 'package:flutter/material.dart';

abstract final class MovenetTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00A6FF),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: Colors.black,
    useMaterial3: true,
    cardTheme: const CardThemeData(
      color: Color(0xFF1B1B1D),
      margin: EdgeInsets.zero,
    ),
  );
}
