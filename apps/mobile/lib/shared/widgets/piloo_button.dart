// Boutons réutilisables — Primary, Outline, Apple, Google.
// Maquette : composants `qktWE`, `XN46N`, `zC8Y5`, `HFgDN` du fichier
// docs/design/piloo-mobile.pen. Tous partagent : cornerRadius
// $radius-md (8), font Manrope 600 ; le padding et la taille de police
// dépendent de `size` (medium par défaut, conforme à la maquette).
//
// États : loading (spinner remplace le contenu) et disabled (opacity
// 0.5, ignore onPressed).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

enum PilooButtonVariant { primary, outline, apple, google }

enum PilooButtonSize { small, medium, large }

class PilooButton extends StatelessWidget {
  const PilooButton({
    required this.label,
    this.variant = PilooButtonVariant.primary,
    this.size = PilooButtonSize.medium,
    this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final PilooButtonVariant variant;
  final PilooButtonSize size;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg, BorderSide? border, IconData? icon}) style =
        switch (variant) {
      PilooButtonVariant.primary => (
          bg: PilooColors.primary,
          fg: PilooColors.textOnPrimary,
          border: null,
          icon: null,
        ),
      PilooButtonVariant.outline => (
          bg: Colors.transparent,
          fg: PilooColors.textPrimary,
          border: const BorderSide(color: PilooColors.border),
          icon: null,
        ),
      PilooButtonVariant.apple => (
          bg: const Color(0xFF111111),
          fg: Colors.white,
          border: null,
          icon: PhosphorIconsFill.appleLogo,
        ),
      PilooButtonVariant.google => (
          bg: PilooColors.surface,
          fg: PilooColors.textPrimary,
          border: const BorderSide(color: PilooColors.border),
          icon: PhosphorIconsRegular.googleLogo,
        ),
    };

    final ({double hPad, double vPad, double fontSize, double iconSize, double spinnerSize}) sizing =
        switch (size) {
      PilooButtonSize.small => (
          hPad: 14,
          vPad: 10,
          fontSize: 13,
          iconSize: 16,
          spinnerSize: 14,
        ),
      PilooButtonSize.medium => (
          hPad: 20,
          vPad: 14,
          fontSize: 15,
          iconSize: 20,
          spinnerSize: 18,
        ),
      PilooButtonSize.large => (
          hPad: 24,
          vPad: 18,
          fontSize: 17,
          iconSize: 22,
          spinnerSize: 22,
        ),
    };

    final textStyle = GoogleFonts.manrope(
      fontSize: sizing.fontSize,
      fontWeight: FontWeight.w600,
      color: style.fg,
    );

    final disabled = onPressed == null || isLoading;

    return Opacity(
      opacity: disabled && !isLoading ? 0.5 : 1.0,
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: style.bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PilooRadius.md),
            side: style.border ?? BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(PilooRadius.md),
            onTap: disabled ? null : onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: sizing.hPad,
                vertical: sizing.vPad,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: sizing.spinnerSize,
                      height: sizing.spinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(style.fg),
                      ),
                    )
                  else ...[
                    if (style.icon != null) ...[
                      Icon(style.icon, size: sizing.iconSize, color: style.fg),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: textStyle,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
