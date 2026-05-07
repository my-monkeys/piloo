// Écran 04 Scan viewfinder (#82) + intégration `mobile_scanner` (#80).
//
// 3 états visuels gérés par `cameraPermissionProvider` :
//   - granted     → MobileScanner actif derrière le viewfinder, scan
//                   GS1 DataMatrix puis route vers /boites/add?cip13=…
//   - denied      → message + bouton "Activer la caméra"
//   - restricted  → message + bouton "Ouvrir les réglages"
//
// Le flash bouton est câblé sur `MobileScannerController.toggleTorch()`.
// Le post-scan (lookup BDPM, branchement nouvelle vs connue) arrive
// avec #84.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/features/scan/data/camera_permission.dart';
import 'package:piloo/shared/gs1/gs1_parser.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan;
  late final MobileScannerController _scanner;
  bool _flash = false;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scanner = MobileScannerController(
      formats: const [BarcodeFormat.dataMatrix],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    // Lance le check permission post-frame pour ne pas builder pendant
    // un setState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePermission();
    });
  }

  Future<void> _ensurePermission() async {
    final ctrl = ref.read(cameraPermissionProvider.notifier);
    await ctrl.refresh();
    final status = ref.read(cameraPermissionProvider);
    if (status == CameraPermissionStatus.unknown ||
        status == CameraPermissionStatus.denied) {
      await ctrl.request();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return; // évite double-fire
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    final parsed = parseGs1(raw);
    final cip13 = parsed.cip13;
    if (cip13 == null) {
      // GS1 illisible ou pas de CIP13 dedans — on laisse l'utilisateur
      // utiliser la saisie manuelle. Toaster sera ajouté dans #85
      // (cas d'erreur scan + fallback).
      return;
    }
    _scanned = true;
    if (!mounted) return;
    context.pushReplacement('${RoutePath.boiteAdd}?cip13=$cip13');
  }

  Future<void> _toggleFlash() async {
    setState(() => _flash = !_flash);
    await _scanner.toggleTorch();
  }

  @override
  void dispose() {
    _scan.dispose();
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(cameraPermissionProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Caméra en arrière-plan plein écran (couvre toute la
          // surface ; le viewfinder est posé par-dessus). N'apparaît
          // qu'avec la permission.
          if (permission == CameraPermissionStatus.granted)
            MobileScanner(
              controller: _scanner,
              onDetect: _onDetect,
              fit: BoxFit.cover,
            ),
          // Voile sombre quand la permission n'est pas encore donnée :
          // évite un flash blanc avant l'init caméra.
          if (permission != CameraPermissionStatus.granted)
            const ColoredBox(color: Color(0xFF111111)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(
                  onClose: () => Navigator.of(context).maybePop(),
                  flashOn: _flash,
                  onToggleFlash: _toggleFlash,
                  flashEnabled:
                      permission == CameraPermissionStatus.granted,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: switch (permission) {
                        CameraPermissionStatus.granted =>
                          _ScannerHud(scan: _scan),
                        CameraPermissionStatus.unknown =>
                          const _PermissionLoading(),
                        CameraPermissionStatus.denied => _PermissionDenied(
                            onRetry: () => ref
                                .read(cameraPermissionProvider.notifier)
                                .request(),
                          ),
                        CameraPermissionStatus.restricted =>
                          _PermissionRestricted(
                            onOpenSettings: () => ref
                                .read(cameraPermissionProvider.notifier)
                                .openAppSystemSettings(),
                          ),
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Center(
                    child: _ManualEntryButton(
                      onTap: () =>
                          context.pushReplacement(RoutePath.boiteAdd),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- États permission ---------------------------------------------

class _PermissionLoading extends StatelessWidget {
  const _PermissionLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.white,
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _PermissionMessage(
      icon: PhosphorIconsRegular.cameraSlash,
      title: 'Caméra non autorisée',
      body:
          'Piloo a besoin de la caméra pour scanner le DataMatrix au dos des boîtes de médicaments.',
      actionLabel: 'Activer la caméra',
      onAction: onRetry,
    );
  }
}

class _PermissionRestricted extends StatelessWidget {
  const _PermissionRestricted({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return _PermissionMessage(
      icon: PhosphorIconsRegular.gear,
      title: 'Caméra bloquée',
      body:
          'Active la caméra dans les réglages système pour pouvoir scanner les boîtes.',
      actionLabel: 'Ouvrir les réglages',
      onAction: onOpenSettings,
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Colors.white),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.fraunces(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.75),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: PilooColors.accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- HUD scanner --------------------------------------------------

class _ScannerHud extends StatelessWidget {
  const _ScannerHud({required this.scan});

  final Animation<double> scan;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        _Viewfinder(scan: scan),
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
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onClose,
    required this.flashOn,
    required this.onToggleFlash,
    required this.flashEnabled,
  });

  final VoidCallback onClose;
  final bool flashOn;
  final VoidCallback onToggleFlash;
  final bool flashEnabled;

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
            onTap: flashEnabled ? onToggleFlash : () {},
            highlighted: flashOn,
            disabled: !flashEnabled,
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
    this.disabled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: highlighted
              ? PilooColors.accent
              : Colors.white.withValues(alpha: disabled ? 0.04 : 0.12),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: Colors.white.withValues(alpha: disabled ? 0.4 : 1),
        ),
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
          AnimatedBuilder(
            animation: scan,
            builder: (_, _) {
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
