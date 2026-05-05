import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
import 'radius.dart';
import 'typography.dart';

ThemeData pilooLightTheme() {
  final textTheme = PilooTypography.textTheme();

  final colorScheme = const ColorScheme.light(
    primary: PilooColors.primary,
    onPrimary: PilooColors.textOnPrimary,
    primaryContainer: PilooColors.primarySoft,
    onPrimaryContainer: PilooColors.primaryHover,
    secondary: PilooColors.accent,
    onSecondary: PilooColors.textOnPrimary,
    secondaryContainer: PilooColors.accentSoft,
    onSecondaryContainer: PilooColors.accent,
    surface: PilooColors.surface,
    onSurface: PilooColors.textPrimary,
    surfaceContainerHighest: PilooColors.surfaceSubtle,
    onSurfaceVariant: PilooColors.textSecondary,
    outline: PilooColors.border,
    error: PilooColors.errorOn,
    onError: PilooColors.textOnPrimary,
    errorContainer: PilooColors.error,
    onErrorContainer: PilooColors.errorOn,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: PilooColors.background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: PilooColors.background,
      foregroundColor: PilooColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: PilooColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: PilooColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        side: const BorderSide(color: PilooColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PilooColors.primary,
        foregroundColor: PilooColors.textOnPrimary,
        elevation: 0,
        textStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PilooRadius.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PilooColors.primary,
        side: const BorderSide(color: PilooColors.border),
        textStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PilooRadius.md),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PilooColors.surface,
      hintStyle: textTheme.bodyMedium?.copyWith(color: PilooColors.textTertiary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PilooRadius.md),
        borderSide: const BorderSide(color: PilooColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PilooRadius.md),
        borderSide: const BorderSide(color: PilooColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PilooRadius.md),
        borderSide: const BorderSide(color: PilooColors.primary, width: 1.5),
      ),
    ),
  );
}
