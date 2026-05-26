// State du tour guidé (#351).
//
// `currentStep` = index dans `onboardingSteps`. Quand on dépasse la
// dernière étape, on désactive `demoMode` et l'overlay disparaît.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:piloo/core/router/router.dart';
import 'package:piloo/features/onboarding/data/demo_mode_provider.dart';
import 'package:piloo/features/onboarding/presentation/onboarding_steps.dart';

class TourStepNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void next() => state = state + 1;
  void prev() => state = state > 0 ? state - 1 : 0;
  void reset() => state = 0;

  /// Démarre (ou redémarre) le tour : enable demoMode, reset l'index à 0
  /// et force la nav vers le tab de la première étape. Force la nav
  /// explicitement même si l'index ne change pas — sinon `ref.listen`
  /// dans l'overlay ne fire pas et l'user reste sur l'écran courant.
  Future<void> start() async {
    state = 0;
    await ref.read(demoModeProvider.notifier).enable();
    final firstTab = onboardingSteps.first.tab;
    if (firstTab != null) {
      ref.read(routerProvider).goNamed(firstTab);
    }
  }

  /// Termine le tour : désactive demoMode et reset l'index. L'overlay
  /// disparaît au prochain rebuild.
  Future<void> finish() async {
    state = 0;
    await ref.read(demoModeProvider.notifier).disable();
  }
}

final tourStepProvider = NotifierProvider<TourStepNotifier, int>(
  TourStepNotifier.new,
);
