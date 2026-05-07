// FAB Scan central — maquette `1dOmG` (ScanB2).
// Halo radial $accent autour, cercle 66 $accent avec icône scan blanche
// et un bord blanc 5px (effet "découpe" dans la tab bar).
//
// Animation press : scale 95% à l'appui, retour à 100% au release ou
// au cancel. AnimatedScale + courbes courtes (90 ms) — donne la bonne
// sensation de "bouton physique" sans rallonger la latence perçue.
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';

class PilooScanFab extends StatefulWidget {
  const PilooScanFab({required this.onTap, super.key});

  final VoidCallback onTap;

  static const double size = 108;
  static const double circleSize = 74;

  @override
  State<PilooScanFab> createState() => _PilooScanFabState();
}

class _PilooScanFabState extends State<PilooScanFab> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Translate.y pour pousser le FAB plus bas (plus visuel "posé sur"
    // la tab bar plutôt que flottant au-dessus). Coordonné avec un
    // bottom padding négatif côté Scaffold (cf. router.dart).
    return Transform.translate(
      offset: const Offset(0, 28),
      child: SizedBox(
        width: PilooScanFab.size,
        height: PilooScanFab.size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Halo radial qui adoucit le passage de la pilule à la
                // sphère accent (visible surtout au-dessus de la zone
                // hors tab bar).
                Container(
                  width: PilooScanFab.size,
                  height: PilooScanFab.size,
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
                  width: PilooScanFab.circleSize,
                  height: PilooScanFab.circleSize,
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
      ),
    );
  }
}
