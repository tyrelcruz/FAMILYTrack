import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFFF4F6FA);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF8E96A8);
  static const divider = Color(0xFFEDEFF3);
  static const shadow = Color(0xFF8E9BB5);

  // Balance card gradient, deep blue (bottom-left) to mint (top-right).
  static const cardGradient = [
    Color(0xFF2C5FDB),
    Color(0xFF3B86E6),
    Color(0xFF4DB5DB),
    Color(0xFF7FDDA8),
  ];
  static const trendUp = Color(0xFF6EE7A0);
  static const trendDown = Color(0xFFFCA5A5);

  static const green = Color(0xFF16A34A);
  static const greenTint = Color(0xFFE3F6EA);
  static const blue = Color(0xFF2563EB);
  static const blueTint = Color(0xFFE6EFFD);
  static const purple = Color(0xFF7356F6);
  static const purpleTint = Color(0xFFEEEAFE);
  static const red = Color(0xFFF04B57);
  static const redTint = Color(0xFFFDE8EA);
  static const orange = Color(0xFFF59E0B);
  static const orangeTint = Color(0xFFFEF1DD);
  static const neutralTint = Color(0xFFEEF0F3);

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: shadow.withValues(alpha: 0.12),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];
}
