// Petit avertissement inline affiché sous un champ "taille de la boîte"
// quand la valeur saisie diverge de celle officielle BDPM. Ne bloque pas
// le save — l'user peut avoir reconditionné ou la BDPM peut être en
// retard. Le bouton "Restaurer" remet la valeur officielle en 1 tap.
//
// Utilisé par :
//   - apps/mobile/lib/features/officine/presentation/officine_screen.dart
//     (_StockAdjustSheet/_PresentationRow)
//   - apps/mobile/lib/features/inventory/presentation/boite_add_screen.dart
//     (_TotalDosesField)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

class BdpmConflictWarning extends StatelessWidget {
  const BdpmConflictWarning({
    super.key,
    required this.officialTotal,
    required this.unitPlural,
    required this.onReset,
  });

  final int officialTotal;
  final String unitPlural;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsFill.warning,
            size: 14,
            color: PilooColors.warningOn,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'BDPM indique $officialTotal $unitPlural.',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: PilooColors.warningOn,
              ),
            ),
          ),
          InkWell(
            onTap: onReset,
            borderRadius: BorderRadius.circular(PilooRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsRegular.arrowCounterClockwise,
                    size: 12,
                    color: PilooColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Restaurer',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: PilooColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
