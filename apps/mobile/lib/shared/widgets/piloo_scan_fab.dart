// FAB Scan central — maquette `1dOmG` (ScanB2).
// Halo radial $accent autour, cercle 66 $accent avec icône scan blanche
// et un bord blanc 5px (effet "découpe" dans la tab bar).
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';

class PilooScanFab extends StatelessWidget {
  const PilooScanFab({required this.onTap, super.key});

  final VoidCallback onTap;

  static const double size = 108;
  static const double circleSize = 74;

  @override
  Widget build(BuildContext context) {
    // Translate.y pour pousser le FAB plus bas (plus visuel "posé sur"
    // la tab bar plutôt que flottant au-dessus). Coordonné avec un
    // bottom padding négatif côté Scaffold (cf. router.dart).
    return Transform.translate(
      offset: const Offset(0, 28),
      child: SizedBox(
        width: size,
        height: size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo radial qui adoucit le passage de la pilule à la
              // sphère accent (visible surtout au-dessus de la zone
              // hors tab bar).
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      PilooColors.accent.withValues(alpha: 0.18),
                      PilooColors.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PilooColors.accent,
                  border: Border.all(
                    color: PilooColors.background,
                    width: 5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PilooColors.accent.withValues(alpha: 0.3),
                      offset: const Offset(0, 6),
                      blurRadius: 18,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  PhosphorIconsRegular.scan,
                  size: 30,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
