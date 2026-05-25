// Keys globales partagées pour les widgets cibles du tour onboarding
// (#351). L'overlay résout la position du widget pointé via la
// `GlobalKey.currentContext.findRenderObject()` et dessine un trou
// dans son backdrop sombre à cet endroit.
//
// Les keys sont attachées par les écrans cibles eux-mêmes (today,
// officine, root scaffold pour le FAB). Si le widget n'est pas monté
// (mauvais tab actif) la résolution renvoie null → l'overlay tombe
// en mode plein écran.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingTargets {
  final GlobalKey scanFab = GlobalKey(debugLabel: 'tour-scan-fab');
  final GlobalKey firstPriseCard = GlobalKey(debugLabel: 'tour-prise-card');
  final GlobalKey firstBoiteCard = GlobalKey(debugLabel: 'tour-boite-card');
  final GlobalKey perimeChip = GlobalKey(debugLabel: 'tour-perime-chip');
}

final onboardingTargetsProvider = Provider<OnboardingTargets>(
  (_) => OnboardingTargets(),
);
