import 'package:flutter/cupertino.dart';
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
    // 검은 배경에서는 Android 기본 전환(확대·페이드)이 거의 보이지 않아
    // 모든 플랫폼에서 iOS식 좌우 슬라이드(뒤로 스와이프 포함)로 통일한다.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1B1B1D),
      margin: EdgeInsets.zero,
    ),
  );
}
