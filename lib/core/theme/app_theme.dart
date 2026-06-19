import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Premium liquid-glass theme for Vybia V2.
///
/// Typography is built explicitly with google_fonts — there is never an empty
/// font family. Manrope carries the UI; Fraunhois... no — Fraunces carries the
/// expressive display headers for an editorial, concierge feel.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    final displayFont = GoogleFonts.fraunces; // warm editorial serif
    final bodyFont = GoogleFonts.manrope; // clean geometric sans

    final textTheme = TextTheme(
      displayLarge: displayFont(
        fontSize: 44,
        height: 1.05,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: displayFont(
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineSmall: displayFont(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: bodyFont(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: bodyFont(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: bodyFont(
        fontSize: 16,
        height: 1.45,
        color: AppColors.textSecondary,
      ),
      bodyMedium: bodyFont(
        fontSize: 14,
        height: 1.45,
        color: AppColors.textSecondary,
      ),
      labelLarge: bodyFont(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: AppColors.textPrimary,
      ),
      labelSmall: bodyFont(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textMuted,
      ),
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      tertiary: AppColors.champagne,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: colorScheme,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
