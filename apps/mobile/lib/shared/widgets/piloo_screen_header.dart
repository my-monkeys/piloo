// Header d'écran principal — maquette `MzLeF` (Screen Header).
// Titre Fraunces 22 + cloche notifications avec petit pastille rouge si
// alertes non lues. La cloche ne sert qu'à signaler — le tap navigue
// vers l'onglet Alertes.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';

class PilooScreenHeader extends StatelessWidget {
  const PilooScreenHeader({
    required this.title,
    this.bellEnabled = true,
    this.bellHasDot = false,
    this.onBellTap,
    super.key,
  });

  final String title;
  final bool bellEnabled;
  final bool bellHasDot;
  final VoidCallback? onBellTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: PilooColors.textPrimary,
            ),
          ),
          if (bellEnabled)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBellTap,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: PilooColors.surfaceSubtle,
                ),
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      PhosphorIconsRegular.bell,
                      size: 20,
                      color: PilooColors.textPrimary,
                    ),
                    if (bellHasDot)
                      Positioned(
                        right: -6,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: PilooColors.accent,
                            border: Border.all(
                              color: PilooColors.background,
                              width: 2,
                            ),
                          ),
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
