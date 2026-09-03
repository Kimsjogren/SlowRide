import 'package:flutter/material.dart';

/// Shared CruizX styling for the AI consent, loading and result dialogs.
class CruizXAiDialogStyle {
  const CruizXAiDialogStyle._();

  static const Color background = Color(0xF20A1A46);
  static const Color accent = Color(0xFF3AA8FF);
  static const Color primary = Color(0xFF1E6BFF);
  static const Color bodyText = Color(0xE6FFFFFF);
  static const Color mutedText = Color(0xA6FFFFFF);

  static RoundedRectangleBorder get shape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24),
    side: const BorderSide(color: Color(0x993AA8FF), width: 1.3),
  );

  static ButtonStyle get primaryButtonStyle => FilledButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  );

  static ButtonStyle get secondaryButtonStyle =>
      TextButton.styleFrom(foregroundColor: accent);

  static const TextStyle titleTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 23,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle bodyTextStyle = TextStyle(
    color: bodyText,
    fontSize: 16,
    height: 1.45,
  );
}
