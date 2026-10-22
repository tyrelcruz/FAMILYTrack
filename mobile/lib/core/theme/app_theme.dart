import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const fontFamily = 'PlusJakartaSans';

  /// Compressed face for big numbers and headings (Vinila Compressed, as in
  /// the reference). It has no ₱ sign, so the regular font fills that in.
  /// Swap to 'BarlowCondensed' for a free alternative.
  static const displayFont = 'VinilaCompressed';
  static const displayFallback = [fontFamily];

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.forest,
          surface: AppColors.background,
        ).copyWith(
          primary: AppColors.forest,
          onPrimary: Colors.white,
          secondary: AppColors.lime,
          onSecondary: AppColors.forest,
        ),
    // Wise-style defaults: lime pills with dark text.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lime,
        foregroundColor: AppColors.forest,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.forest),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.forest,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.forest,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    textTheme: ThemeData.light().textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
  );
}
