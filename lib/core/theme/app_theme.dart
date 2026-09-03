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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xF20A1F63),
        indicatorColor: const Color(0x441E6BFF),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF3AA8FF), size: 24);
          }
          return const IconThemeData(color: Color(0x99FFFFFF), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Color(0xFF3AA8FF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(color: Color(0x99FFFFFF), fontSize: 12);
        }),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        color: Color(0xCC0A1A46),
      ),
    );
  }
}
