import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

abstract class PilooTypography {
  static TextTheme textTheme() {
    final display = GoogleFonts.fraunces(
      fontSize: 32,
      fontWeight: FontWeight.w500,
      color: PilooColors.textPrimary,
    );
    final titleXl = GoogleFonts.fraunces(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: PilooColors.textPrimary,
    );
    final titleLg = GoogleFonts.fraunces(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: PilooColors.textPrimary,
    );
    final titleMd = GoogleFonts.fraunces(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: PilooColors.textPrimary,
    );
    final bodyLg = GoogleFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: PilooColors.textPrimary,
    );
    final bodyMd = GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: PilooColors.textPrimary,
    );
    final bodySm = GoogleFonts.manrope(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: PilooColors.textSecondary,
    );
    final caption = GoogleFonts.manrope(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: PilooColors.textSecondary,
    );
    // Eyebrow / section label : Manrope 600 11px uppercase
    final label = GoogleFonts.manrope(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: PilooColors.textTertiary,
    );

    return TextTheme(
      displayLarge: display,
      displayMedium: display,
      displaySmall: display,
      headlineLarge: titleXl,
      headlineMedium: titleXl,
      headlineSmall: titleLg,
      titleLarge: titleLg,
      titleMedium: titleMd,
      titleSmall: titleMd,
      bodyLarge: bodyLg,
      bodyMedium: bodyMd,
      bodySmall: bodySm,
      labelLarge: caption,
      labelMedium: caption,
      labelSmall: label,
    );
  }
}
