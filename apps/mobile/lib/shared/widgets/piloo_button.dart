// Boutons réutilisables — Primary, Outline, Apple, Google.
// Maquette : composants `qktWE`, `XN46N`, `zC8Y5`, `HFgDN` du fichier
// docs/design/piloo-mobile.pen. Tous partagent : padding [14,20], gap 10,
// cornerRadius $radius-md (8), font Manrope 15 / 600.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

enum PilooButtonVariant { primary, outline, apple, google }

class PilooButton extends StatelessWidget {
  const PilooButton({
    required this.label,
    this.variant = PilooButtonVariant.primary,
    this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final PilooButtonVariant variant;
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

    final textStyle = GoogleFonts.manrope(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: style.fg,
    );

    final disabled = onPressed == null || isLoading;

    return Opacity(
      opacity: disabled && !isLoading ? 0.5 : 1.0,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(style.fg),
                    ),
                  )
                else ...[
                  if (style.icon != null) ...[
                    Icon(style.icon, size: 20, color: style.fg),
                    const SizedBox(width: 10),
                  ],
                  Text(label, style: textStyle),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
