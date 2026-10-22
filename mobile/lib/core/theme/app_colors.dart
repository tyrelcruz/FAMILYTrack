import 'package:flutter/material.dart';

/// Cleo-inspired palette: deep royal indigo, mint highlights, gold and
/// purple accents, white rounded cards on a soft lavender-white page.
class AppColors {
  AppColors._();

  // Brand. `lime` is the bright highlight (buttons, bars); `forest` the deep
  // brand color (headers, text on highlights). Names kept so every screen
  // follows the theme.
  static const lime = Color(0xFF6EEDB0);
  static const forest = Color(0xFF2420A3);
  static const gold = Color(0xFFFFD43B);
  static const lilac = Color(0xFFB79CFF);
  static const tangerine = Color(0xFFFFA94D);

  // Surfaces and text
  static const background = Color(0xFFF4F4FA);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF111127);
  static const textSecondary = Color(0xFF4B4B63);
  static const textMuted = Color(0xFF8A8AA3);
  static const divider = Color(0xFFE7E7F1);
  static const shadow = Color(0xFF2420A3);

  /// Indigo cards (family / member / group).
  static const cardGradient = [
    Color(0xFF1C1990),
    Color(0xFF2420A3),
    Color(0xFF2E2AB8),
    Color(0xFF3B37CC),
  ];

  /// Home header: solid indigo.
  static const heroGradient = [
    Color(0xFF2420A3),
    Color(0xFF2420A3),
    Color(0xFF2420A3),
    Color(0xFF2622AA),
  ];

  /// Fill for bars and other "active" accents.
  static const accentBlue = lime;
  static const progressTrack = Color(0xFFE6E6F2);
  static const expenseRed = Color(0xFFE5484D);

  // Positive / negative on dark cards.
  static const trendUp = lime;
  static const trendDown = Color(0xFFFFB4B4);

  // Tints and accents. `blue` is the link/icon color.
  static const green = Color(0xFF14A363);
  static const greenTint = Color(0xFFE3FBEF);
  static const blue = Color(0xFF3B37DB);
  static const blueTint = Color(0xFFECEBFF);
  static const purple = Color(0xFF7C5CF0);
  static const purpleTint = Color(0xFFF0EBFF);
  static const red = Color(0xFFE5484D);
  static const redTint = Color(0xFFFDE8E8);
  static const orange = Color(0xFFF08C00);
  static const orangeTint = Color(0xFFFFF0DC);
  static const neutralTint = Color(0xFFEAEAF3);

  /// Flat: no drop shadows.
  static List<BoxShadow> softShadow = const [];
}
