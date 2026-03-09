import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData dark() {
    const surface = Color(0xFF0A1F63);
    const primary = Color(0xFF1E6BFF);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Color(0x990A1F7A),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0x990A1F7A),
        indicatorColor: Color(0x5537C871),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        color: Color(0xCC0A1A46),
      ),
    );
  }
}
