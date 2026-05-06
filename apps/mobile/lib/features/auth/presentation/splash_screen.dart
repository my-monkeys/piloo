// Écran A1 Splash + redirection auth (#58).
//
// Maquette : `r3pdR` du fichier docs/design/piloo-mobile.pen
//
// Logique :
//  - On lit `sessionProvider` (charge la session persistée depuis
//    `flutter_secure_storage` au boot — cf. #46).
//  - On garde un délai mini de 1.2s pour que le splash respire
//    (le sessionProvider résout en quelques ms sur la plupart des
//    devices).
//  - Session présente → /today (et on remplace la route, pas de back).
//  - Session absente → /welcome (idem).
//
// Easter egg dev : 5 taps successifs (≤ 1s entre chaque) sur le logo
// poussent vers /_dev (DevHomeScreen — liste cliquable des écrans M1).
// Pratique pour la review design tant que les écrans ne sont pas tous
// implémentés. Le bouton n'est jamais visible visuellement.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const Duration _minSplashDuration = Duration(milliseconds: 1200);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  int _logoTapCount = 0;
  Timer? _tapResetTimer;
  Timer? _redirectTimer;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    unawaited(_scheduleRedirect());
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _redirectTimer?.cancel();
    super.dispose();
  }

  Future<void> _scheduleRedirect() async {
    // Lit la session persistée (in-memory en tests, secure storage en prod).
    final session = await ref.read(sessionProvider.future);
    if (!mounted || _redirected) return;
    // Timer cancellable — annulé au dispose ou si on entre dans le menu
    // dev avant que le délai mini ne soit écoulé.
    _redirectTimer = Timer(SplashScreen._minSplashDuration, () {
      if (!mounted || _redirected) return;
      _redirected = true;
      final destination = session != null ? RoutePath.today : RoutePath.welcome;
      context.go(destination);
    });
  }

  void _onLogoTap() {
    _logoTapCount++;
    _tapResetTimer?.cancel();
    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      _redirected = true;
      _redirectTimer?.cancel();
      context.push(RoutePath.dev);
      return;
    }
    _tapResetTimer = Timer(const Duration(seconds: 1), () {
      _logoTapCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 80),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onLogoTap,
                      child: const _LogoBadge(),
                    ),
                    const SizedBox(height: 20),
                    const _Wordmark(),
                    const SizedBox(height: 20),
                    Text(
                      'Le carnet numérique de médicaments',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fraunces(
                        fontSize: 16,
                        color: PilooColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 60,
              child: Center(child: _LoaderDots()),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          // 135° en CSS = top-left → bottom-right.
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PilooColors.primarySoft, PilooColors.accentSoft],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF252A30).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 84,
        height: 84,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: PilooColors.surface,
        ),
        alignment: Alignment.center,
        child: const Icon(
          PhosphorIconsFill.firstAidKit,
          size: 44,
          color: PilooColors.primary,
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.fraunces(
      fontSize: 56,
      fontWeight: FontWeight.w500,
      letterSpacing: -1,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('pil', style: base.copyWith(color: PilooColors.primary)),
        Text('oo', style: base.copyWith(color: PilooColors.accent)),
      ],
    );
  }
}

class _LoaderDots extends StatefulWidget {
  const _LoaderDots();

  @override
  State<_LoaderDots> createState() => _LoaderDotsState();
}

class _LoaderDotsState extends State<_LoaderDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1200),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 3 phases (0, 1/3, 2/3) — chaque dot se "remplit" à son tour.
        final phase = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _Dot(active: _isActive(phase, i)),
            ],
          ],
        );
      },
    );
  }

  bool _isActive(double phase, int index) {
    final start = index / 3;
    final end = (index + 1) / 3;
    return phase >= start && phase < end;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? PilooColors.primary : PilooColors.primarySoft,
      ),
    );
  }
}
