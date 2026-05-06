// Toast transient — slide depuis le haut, auto-dismiss après 3s, tap pour
// fermer. À utiliser pour toutes les notifications transitoires de
// l'app (erreurs, succès, info). Préféré aux bannières inline parce que :
//
//  1. Pas d'impact sur le layout du formulaire (l'écran ne saute pas
//     quand l'erreur apparaît).
//  2. Vue native sur mobile (correspond à la convention iOS/Android).
//  3. Empilement propre via `OverlayEntry`.
//
// Pas de dépendance à `ScaffoldMessenger` — fonctionne tant qu'il y a un
// `Overlay` au-dessus (toujours le cas via `MaterialApp`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

enum PilooToastVariant { error, success, info }

abstract class PilooToast {
  static const Duration _autoDismiss = Duration(seconds: 3);
  static const Duration _animation = Duration(milliseconds: 220);

  static void error(BuildContext context, String message) =>
      _show(context, message, PilooToastVariant.error);

  static void success(BuildContext context, String message) =>
      _show(context, message, PilooToastVariant.success);

  static void info(BuildContext context, String message) =>
      _show(context, message, PilooToastVariant.info);

  static void _show(
    BuildContext context,
    String message,
    PilooToastVariant variant,
  ) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _PilooToastWidget(
        message: message,
        variant: variant,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _PilooToastWidget extends StatefulWidget {
  const _PilooToastWidget({
    required this.message,
    required this.variant,
    required this.onDismiss,
  });

  final String message;
  final PilooToastVariant variant;
  final VoidCallback onDismiss;

  @override
  State<_PilooToastWidget> createState() => _PilooToastWidgetState();
}

class _PilooToastWidgetState extends State<_PilooToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: PilooToast._animation,
    vsync: this,
  );
  late final Animation<double> _slide =
      Tween<double>(begin: -1, end: 0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dismissTimer = Timer(PilooToast._autoDismiss, _dismiss);
  }

  Future<void> _dismiss() async {
    _dismissTimer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg, IconData icon}) palette = switch (widget.variant) {
      PilooToastVariant.error => (
          bg: PilooColors.error,
          fg: PilooColors.errorOn,
          icon: PhosphorIconsRegular.warningCircle,
        ),
      PilooToastVariant.success => (
          bg: PilooColors.success,
          fg: PilooColors.successOn,
          icon: PhosphorIconsRegular.checkCircle,
        ),
      PilooToastVariant.info => (
          bg: PilooColors.info,
          fg: PilooColors.infoOn,
          icon: PhosphorIconsRegular.info,
        ),
    };

    return SafeArea(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Align(
            alignment: Alignment.topCenter,
            child: FractionalTranslation(
              translation: Offset(0, _slide.value),
              child: Opacity(opacity: _fade.value, child: child),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: BorderRadius.circular(PilooRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(palette.icon, size: 20, color: palette.fg),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: palette.fg,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
