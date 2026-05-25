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
import 'package:piloo/features/inventory/data/boites_provider.dart';
import 'package:piloo/features/inventory/presentation/quick_actions_sheet.dart';
import 'package:piloo/features/officines/data/active_officine_provider.dart';
import 'package:piloo/features/scan/data/camera_permission.dart';
import 'package:piloo/features/scan/data/scan_result.dart';
import 'package:piloo/features/scan/presentation/manual_cip_sheet.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/partages/data/partages_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_lookup_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_provider.dart';
import 'package:piloo/shared/gs1/gs1_parser.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

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

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned) return; // évite double-fire
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    final parsed = parseGs1(raw);
    final scanResult = ScanResult.fromGs1(parsed);
    if (scanResult == null) {
      // GS1 illisible ou pas de CIP13 dedans (DataMatrix non-pharma,
      // ex: code interne d'inventaire d'une grande surface). On
      // toast une fois et on garde le scanner actif pour permettre
      // un nouvel essai. AC #85 : "Messages d'erreur clairs".
      _onNonPharmaCode();
      return;
    }
    _scanned = true;
    // Pousse le résultat dans le provider AVANT de naviguer pour que
    // l'écran cible puisse le lire dès son build initial.
    ref.read(scanResultProvider.notifier).set(scanResult);
    if (!mounted) return;
    // Pre-check : si l'officine active a déjà une boîte avec ce
    // (cip13, lot), on saute boite_add et on ouvre direct la modale
    // quick-actions. UX nettement plus rapide que de devoir taper
    // "Ajouter" pour se taper un 409.
    final existing = _findExistingForScan(scanResult);
    if (existing != null) {
      await _showExistingBoiteSheet(existing, scanResult.cip13);
      return;
    }
    if (!mounted) return;
    context.pushReplacement(RoutePath.boiteAdd);
  }

  /// Cherche dans le cache Riverpod local une boîte de l'officine
  /// active qui matche le scan. Si data pas encore chargée, retourne
  /// null — le 409 fallback côté boite_add prendra le relais.
  api.Boite? _findExistingForScan(ScanResult sr) {
    final officine = ref.read(activeOfficineProvider).valueOrNull;
    if (officine == null) return null;
    final boites = ref.read(boitesProvider(officine.id)).valueOrNull;
    if (boites == null) return null;
    for (final b in boites) {
      if (b.cip13 != sr.cip13) continue;
      // Match strict : même lot (ou même serial si fourni). Sans lot
      // côté scan, on ne match pas — l'user veut ajouter sans préciser
      // le lot, le flow ajout reste cohérent.
      if (sr.serial != null && b.numeroSerie == sr.serial) return b;
      if (sr.lot != null && b.lot == sr.lot) return b;
    }
    return null;
  }

  Future<void> _showExistingBoiteSheet(api.Boite existing, String cip13) async {
    final lookup =
        await ref.read(bdpmLookupProvider(cip13).future).catchError((_) => null);
    // substances ne sont disponibles que via SQLite local (pas exposé via
    // l'API REST). On lit en parallèle.
    final localBdpm = ref.read(bdpmDbProvider).valueOrNull?.findByCip13(cip13);
    if (!mounted) return;
    final officine = ref.read(activeOfficineProvider).valueOrNull;
    final officineLabel = officine?.nom ?? 'Maison';
    final medName = lookup?.denomination ?? 'Médicament';
    final peremption = DateTime(
      existing.peremption.year,
      existing.peremption.month,
      existing.peremption.day,
    );
    final partages =
        ref.read(partagesProvider(existing.officineId)).valueOrNull;
    final session = ref.read(sessionProvider).value;
    final hasOtherMembers = partages != null &&
        partages.members.any((m) => m.userId != session?.userId);
    final action = await showQuickActionsSheet(
      context,
      info: QuickActionsContext(
        officineLabel: officineLabel,
        medicamentName: medName,
        cip13: existing.cip13,
        recognizedFromBdpm: true,
        peremptionDate: peremption,
        canAddAnotherBox: true,
        substances: localBdpm?.substances ?? const [],
        hasOtherMembers: hasOtherMembers,
      ),
    );
    if (!mounted) return;
    if (action == QuickAction.addAnotherBox) {
      await updateBoite(
        ref,
        boiteId: existing.id,
        officineId: existing.officineId,
        nombreBoites: existing.nombreBoites + 1,
      );
      if (!mounted) return;
      PilooToast.success(
        context,
        'Boîte ajoutée (${existing.nombreBoites + 1} au total).',
      );
    } else if (action == QuickAction.seeInfo) {
      context.pushReplacement(RoutePath.medicamentInfo(existing.cip13));
      return;
    }
    // Dans tous les cas (action choisie ou sheet dismissed), on revient
    // sur l'écran d'avant le scan plutôt que de rester sur l'écran scan
    // — sinon le scanner re-fire au prochain frame.
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePath.officine);
    }
  }

  DateTime? _lastNonPharmaToast;

  void _onNonPharmaCode() {
    // Évite de spammer le toast quand la caméra capte plusieurs frames
    // consécutifs du même mauvais code-barres.
    final now = DateTime.now();
    if (_lastNonPharmaToast != null &&
        now.difference(_lastNonPharmaToast!) < const Duration(seconds: 3)) {
      return;
    }
    _lastNonPharmaToast = now;
    if (!mounted) return;
    PilooToast.error(
      context,
      "Ce code-barres n'est pas une boîte de médicament. Saisis le CIP à la main.",
    );
  }

  Future<void> _openManualCip() async {
    final result = await showManualCipSheet(context);
    if (!mounted) return;
    if (result != null) {
      ref.read(scanResultProvider.notifier).set(result);
    }
    // Que l'utilisateur ait saisi un CIP ou cliqué "Continuer sans CIP",
    // on route vers /boites/add. Le screen lit le scan_result et tombe
    // sur "Saisie manuelle" si null.
    if (!mounted) return;
    context.pushReplacement(RoutePath.boiteAdd);
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
                  onClose: () => context.canPop()
                      ? context.pop()
                      : context.go(RoutePath.today),
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
                    child: _ManualEntryButton(onTap: _openManualCip),
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
