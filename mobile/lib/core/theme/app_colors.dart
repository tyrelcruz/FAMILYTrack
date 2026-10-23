import 'package:flutter/material.dart';

/// White pages with teal accents: solid teal for main actions, deep teal for
/// links and icons, mint for soft highlights, gold and purple as extras.
class AppColors {
  AppColors._();

  // Brand. `lime` is the bright highlight (buttons, bars); `forest` the deep
  // brand color (headers, text on highlights). Names kept so every screen
  // follows the theme.
  static const lime = Color(0xFF12B886);
  static const forest = Color(0xFF0B7A5C);

  /// Bright mint for small labels, e.g. the coin chart's Income / Limit.
  static const mintBright = Color(0xFF6EEDB0);
  static const gold = Color(0xFFFFD43B);
  static const lilac = Color(0xFFB79CFF);
  static const tangerine = Color(0xFFFFA94D);

  // Teal accents of the white "breakdown" pages.
  static const teal = Color(0xFF12B886);
  static const tealDark = Color(0xFF0B7A5C);
  static const mint = Color(0xFFDDF6EC);
  static const mintTrack = Color(0xFFD6EFE6);

  // Surfaces and text
  static const background = Color(0xFFF4F7F6);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF101B18);
  static const textSecondary = Color(0xFF4A5753);
  static const textMuted = Color(0xFF8A9792);
  static const divider = Color(0xFFE2EAE6);
  static const shadow = Color(0xFF0B7A5C);

  /// Deep teal cards (family / member / group), matching the teal accents.
  static const cardGradient = [
    Color(0xFF075E47),
    Color(0xFF0B7A5C),
    Color(0xFF0E9170),
    Color(0xFF14A882),
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
  static const progressTrack = Color(0xFFE0EAE6);
  static const expenseRed = Color(0xFFE5484D);

  // Positive / negative on dark cards.
  static const trendUp = lime;
  static const trendDown = Color(0xFFFFB4B4);

  // Tints and accents. `blue` is the link/icon color.
  static const green = Color(0xFF14A363);
  static const greenTint = Color(0xFFE1F6EC);
  static const blue = Color(0xFF0B7A5C);
  static const blueTint = Color(0xFFDDF6EC);
  static const purple = Color(0xFF7C5CF0);
  static const purpleTint = Color(0xFFF0EBFF);
  static const red = Color(0xFFE5484D);
  static const redTint = Color(0xFFFDE8E8);
  static const orange = Color(0xFFF08C00);
  static const orangeTint = Color(0xFFFFF0DC);
  static const neutralTint = Color(0xFFE9EFEC);

  /// Soft lift for white cards on white pages.
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF101B18).withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
}
