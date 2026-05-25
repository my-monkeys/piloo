// Overlay du tour guidé (#351).
//
// Mounté en haut du widget tree (cf. app.dart) au-dessus du router.
// Visible uniquement quand `demoMode = true`. Affiche une card en bas
// de l'écran avec le titre + body de l'étape courante + actions.
//
// Pour rester non-intrusif : ne couvre pas tout l'écran, juste un
// halo sombre semi-transparent en bas + la card. L'user voit toujours
// l'écran d'arrière-plan (peuplé par les fixtures démo) et peut
// interagir si besoin.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/router.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/onboarding/data/demo_mode_provider.dart';
import 'package:piloo/features/onboarding/presentation/onboarding_steps.dart';
import 'package:piloo/features/onboarding/presentation/onboarding_tour_provider.dart';

class OnboardingOverlay extends ConsumerWidget {
  const OnboardingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoMode = ref.watch(demoModeProvider).valueOrNull ?? false;
    if (!demoMode) return const Positioned(left: 0, top: 0, child: SizedBox.shrink());

    // Nav auto au changement d'étape : on lit le router via le provider
    // (override dans main.dart), pas via context.goNamed qui ne marche
    // pas depuis le MaterialApp.builder (hors Navigator).
    ref.listen<int>(tourStepProvider, (prev, next) {
      if (prev == next || next >= onboardingSteps.length) return;
      final tab = onboardingSteps[next].tab;
      if (tab == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(routerProvider).goNamed(tab);
      });
    });

    final stepIndex = ref.watch(tourStepProvider);
    if (stepIndex >= onboardingSteps.length) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final step = onboardingSteps[stepIndex];
    final isLast = stepIndex == onboardingSteps.length - 1;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 110, // au-dessus de la tab bar
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
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
      ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.primary, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    );
  }
}
