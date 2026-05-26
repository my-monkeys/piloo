// Overlay du tour guidé (#351).
//
// Mounté en haut du widget tree (cf. app.dart) au-dessus du router.
// Visible uniquement quand `demoMode = true`. Affiche :
//   1. Un backdrop semi-transparent plein écran
//   2. Un trou (spotlight) autour du widget cible si le step en a un,
//      résolu via `GlobalKey.currentContext.findRenderObject()`
//   3. Une card flottante avec titre + body + actions, positionnée
//      au-dessus ou en-dessous de la cible selon sa position écran
//
// Les positions du trou sont recalculées à chaque changement de step
// avec un délai après nav (le widget cible doit avoir le temps d'être
// monté dans le nouveau tab).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/router.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/onboarding/data/demo_mode_provider.dart';
import 'package:piloo/features/onboarding/data/onboarding_targets.dart';
import 'package:piloo/features/onboarding/presentation/onboarding_steps.dart';
import 'package:piloo/features/onboarding/presentation/onboarding_tour_provider.dart';

class OnboardingOverlay extends ConsumerStatefulWidget {
  const OnboardingOverlay({super.key});

  @override
  ConsumerState<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends ConsumerState<OnboardingOverlay> {
  Rect? _targetRect;
  int? _lastStep;
  bool _refreshScheduled = false;

  GlobalKey? _keyFor(TourTarget t) {
    final targets = ref.read(onboardingTargetsProvider);
    return switch (t) {
      TourTarget.none => null,
      TourTarget.scanFab => targets.scanFab,
      TourTarget.firstPriseCard => targets.firstPriseCard,
      TourTarget.firstBoiteCard => targets.firstBoiteCard,
      TourTarget.perimeChip => targets.perimeChip,
    };
  }

  void _refreshTargetRect() {
    if (!mounted) return;
    final demoMode = ref.read(demoModeProvider).valueOrNull ?? false;
    if (!demoMode) {
      if (_targetRect != null) setState(() => _targetRect = null);
      return;
    }
    final stepIndex = ref.read(tourStepProvider);
    if (stepIndex >= onboardingSteps.length) {
      if (_targetRect != null) setState(() => _targetRect = null);
      return;
    }
    final key = _keyFor(onboardingSteps[stepIndex].target);
    if (key == null) {
      if (_targetRect != null) setState(() => _targetRect = null);
      return;
    }
    final ctx = key.currentContext;
    if (ctx == null) {
      // Widget pas encore monté (tab pas encore visible) : on
      // re-tente après la prochaine frame.
      _scheduleRefresh();
      return;
    }
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      _scheduleRefresh();
      return;
    }
    final pos = box.localToGlobal(Offset.zero);
    final rect = pos & box.size;
    if (rect != _targetRect) {
      setState(() => _targetRect = rect);
    }
  }

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      _refreshTargetRect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final demoMode = ref.watch(demoModeProvider).valueOrNull ?? false;
    if (!demoMode) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }

    // Nav auto au changement d'étape (cf. start() du TourStepNotifier
    // pour le premier step).
    ref.listen<int>(tourStepProvider, (prev, next) {
      if (next >= onboardingSteps.length) return;
      final tab = onboardingSteps[next].tab;
      if (tab != null && prev != next) {
        ref.read(routerProvider).goNamed(tab);
      }
      // Laisse le temps au nouveau tab de se monter avant de
      // recalculer le rect (animation tab + 1 frame de layout).
      Future.delayed(const Duration(milliseconds: 280), _refreshTargetRect);
    });

    final stepIndex = ref.watch(tourStepProvider);
    if (stepIndex >= onboardingSteps.length) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }

    // Détecte changement de step (incluant le tout premier build) pour
    // forcer un refresh du rect même si la nav n'a pas tiré le listen.
    if (stepIndex != _lastStep) {
      _lastStep = stepIndex;
      _scheduleRefresh();
    }

    final step = onboardingSteps[stepIndex];
    final isLast = stepIndex == onboardingSteps.length - 1;
    final hasTarget = step.target != TourTarget.none && _targetRect != null;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Backdrop avec trou (ou plein écran si pas de target).
            // GestureDetector opaque pour absorber les taps qui passeraient
            // à travers et déclencheraient des actions sur l'app derrière
            // (mode "Suivant uniquement").
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(
                  painter: _BackdropPainter(
                    hole: hasTarget ? _targetRect : null,
                  ),
                ),
              ),
            ),
            // Halo animé autour du trou pour attirer l'œil.
            if (hasTarget)
              Positioned.fromRect(
                rect: _targetRect!.inflate(8),
                child: IgnorePointer(
                  child: _PulsingHalo(),
                ),
              ),
            // Card de tooltip.
            _TooltipPositioner(
              targetRect: hasTarget ? _targetRect : null,
              child: _TourCard(
                step: step,
                index: stepIndex,
                total: onboardingSteps.length,
                isLast: isLast,
                onNext: () async {
                  if (isLast) {
                    await ref.read(tourStepProvider.notifier).finish();
                  } else {
                    ref.read(tourStepProvider.notifier).next();
                  }
                },
                onSkip: () async {
                  await ref.read(tourStepProvider.notifier).finish();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Place la card de tooltip intelligemment : si une cible existe, on
/// décide au-dessus ou en-dessous selon où elle est ; sinon centré bas.
class _TooltipPositioner extends StatelessWidget {
  const _TooltipPositioner({required this.targetRect, required this.child});

  final Rect? targetRect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final safeBottom = media.padding.bottom;
    const cardMargin = 16.0;
    const cardGap = 20.0;

    if (targetRect == null) {
      // Pas de cible : centré, juste au-dessus de la tab bar.
      return Positioned(
        left: cardMargin,
        right: cardMargin,
        bottom: 110 + safeBottom,
        child: child,
      );
    }

    final target = targetRect!;
    final aboveSpace = target.top;
    final belowSpace = screenH - target.bottom;

    // Préfère en-dessous sauf si la cible est dans le tiers inférieur
    // (ex: scan FAB, tab bar) où on n'a plus la place.
    final placeAbove = belowSpace < 220 || aboveSpace > belowSpace;

    if (placeAbove) {
      final bottom = screenH - target.top + cardGap;
      return Positioned(
        left: cardMargin,
        right: cardMargin,
        bottom: bottom,
        child: child,
      );
    } else {
      final top = target.bottom + cardGap;
      return Positioned(
        left: cardMargin,
        right: cardMargin,
        top: top,
        child: child,
      );
    }
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.hole});

  final Rect? hole;
  static const _radius = 14.0;
  static const _padding = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final full = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(full, paint);
      return;
    }
    final inflated = hole!.inflate(_padding);
    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(inflated, const Radius.circular(_radius)),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, holePath),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.hole != hole;
}

/// Halo doux qui pulse autour du trou pour attirer le regard.
class _PulsingHalo extends StatefulWidget {
  @override
  State<_PulsingHalo> createState() => _PulsingHaloState();
}

class _PulsingHaloState extends State<_PulsingHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: PilooColors.primary.withValues(alpha: 0.7 + t * 0.3),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: PilooColors.primary.withValues(alpha: 0.25 + t * 0.25),
                blurRadius: 16 + t * 12,
                spreadRadius: 1 + t * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  final OnboardingStep step;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PilooColors.surface,
            borderRadius: BorderRadius.circular(PilooRadius.lg),
            border: Border.all(color: PilooColors.primary, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: PilooColors.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${index + 1} / $total',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PilooColors.primary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSkip,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        'Passer',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: PilooColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                step.title,
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.body,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: PilooColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: PilooColors.primary,
                  borderRadius: BorderRadius.circular(PilooRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(PilooRadius.md),
                    onTap: onNext,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLast ? 'Commencer' : 'Suivant',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isLast
                                ? PhosphorIconsBold.check
                                : PhosphorIconsBold.arrowRight,
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
