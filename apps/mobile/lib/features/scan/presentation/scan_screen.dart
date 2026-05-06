// Écran 04 Scan viewfinder (#82).
// Maquette : `EkaH0` du fichier docs/design/piloo-mobile.pen.
//
// Ce ticket couvre l'UI seule. L'intégration `mobile_scanner` +
// permission caméra runtime arrive avec #80. Pour l'instant le
// viewfinder est purement décoratif (la zone derrière reste noire).
//
// Composants :
//  - Fond `#111111`
//  - Top bar : close (push pop) + flash toggle (no-op tant que pas
//    de caméra)
//  - Eyebrow "SCANNER UNE BOÎTE" Manrope 11 700 1.5LS, blanc 50%
//  - Viewfinder 260×260 : 4 brackets accent 3px round-cap + scan line
//    accent 2px qui descend en boucle (1.4s)
//  - Helper text "Cadre le DataMatrix au dos de la boîte"
//  - Bouton "Saisie manuelle" en bas — pill blanc15 + bord blanc30
//    + icône keyboard. Tap → /boites/add (pour l'instant, c'est
//    placeholder)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(
              onClose: () => Navigator.of(context).maybePop(),
              flashOn: _flash,
              onToggleFlash: () => setState(() => _flash = !_flash),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SCANNER UNE BOÎTE',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _Viewfinder(scan: _scan),
                    const SizedBox(height: 28),
                    Text(
                      'Cadre le DataMatrix au dos de la boîte',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Center(
                child: _ManualEntryButton(
                  onTap: () {
                    // Placeholder — quand le scan sera réel, "saisie
                    // manuelle" pré-remplit la boîte sans CIP. Pour
                    // l'instant on push le placeholder de #89.
                    Navigator.of(context).pushReplacementNamed(
                      RoutePath.boiteAdd,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onClose,
    required this.flashOn,
    required this.onToggleFlash,
  });

  final VoidCallback onClose;
  final bool flashOn;
  final VoidCallback onToggleFlash;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlassButton(
            icon: PhosphorIconsRegular.x,
            onTap: onClose,
          ),
          _GlassButton(
            icon: flashOn
                ? PhosphorIconsFill.lightning
                : PhosphorIconsRegular.lightning,
            onTap: onToggleFlash,
            highlighted: flashOn,
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: highlighted
              ? PilooColors.accent
              : Colors.white.withValues(alpha: 0.12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.scan});

  final Animation<double> scan;

  static const double _size = 260;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 4 brackets aux coins.
          const Positioned(
            top: 0,
            left: 0,
            child: _Bracket(corner: _Corner.topLeft),
          ),
          const Positioned(
            top: 0,
            right: 0,
            child: _Bracket(corner: _Corner.topRight),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            child: _Bracket(corner: _Corner.bottomLeft),
          ),
          const Positioned(
            bottom: 0,
            right: 0,
            child: _Bracket(corner: _Corner.bottomRight),
          ),
          // Scan line accent qui descend en boucle.
          AnimatedBuilder(
            animation: scan,
            builder: (_, _) {
              // Va de y=8 (juste sous le bracket haut) à y=_size-10
              final y = 8 + (_size - 18) * scan.value;
              return Positioned(
                top: y,
                left: 12,
                right: 12,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: PilooColors.accent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: PilooColors.accent.withValues(alpha: 0.7),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _Bracket extends StatelessWidget {
  const _Bracket({required this.corner});

  final _Corner corner;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(40, 40),
      painter: _BracketPainter(corner: corner),
    );
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter({required this.corner});

  final _Corner corner;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PilooColors.accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    switch (corner) {
      case _Corner.topLeft:
        path.moveTo(0, 18);
        path.lineTo(0, 0);
        path.lineTo(18, 0);
      case _Corner.topRight:
        path.moveTo(size.width - 18, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, 18);
      case _Corner.bottomLeft:
        path.moveTo(0, size.height - 18);
        path.lineTo(0, size.height);
        path.lineTo(18, size.height);
      case _Corner.bottomRight:
        path.moveTo(size.width - 18, size.height);
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, size.height - 18);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) =>
      oldDelegate.corner != corner;
}

class _ManualEntryButton extends StatelessWidget {
  const _ManualEntryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsRegular.keyboard,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'Saisie manuelle',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
