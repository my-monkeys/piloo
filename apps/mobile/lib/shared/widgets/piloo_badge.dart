// Badge / pill réutilisable (#53).
//
// Petit indicateur d'état (Périmé / Actif / Stock bas / etc.) — utilisé
// sur les cards d'inventaire et la timeline. 6 tons mappés sur les
// paires color/colorOn de PilooColors.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

enum PilooBadgeTone { neutral, success, warning, error, info, primary }

class PilooBadge extends StatelessWidget {
  const PilooBadge({
    required this.label,
    this.tone = PilooBadgeTone.neutral,
    super.key,
  });

  final String label;
  final PilooBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg}) palette = switch (tone) {
      PilooBadgeTone.neutral => (
          bg: PilooColors.surfaceSubtle,
          fg: PilooColors.textSecondary,
        ),
      PilooBadgeTone.success => (
          bg: PilooColors.success,
          fg: PilooColors.successOn,
        ),
      PilooBadgeTone.warning => (
          bg: PilooColors.warning,
          fg: PilooColors.warningOn,
        ),
      PilooBadgeTone.error => (bg: PilooColors.error, fg: PilooColors.errorOn),
      PilooBadgeTone.info => (bg: PilooColors.info, fg: PilooColors.infoOn),
      PilooBadgeTone.primary => (
          bg: PilooColors.primarySoft,
          fg: PilooColors.primary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(PilooRadius.full),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
