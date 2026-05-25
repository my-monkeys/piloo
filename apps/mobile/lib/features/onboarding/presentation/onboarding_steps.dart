// Étapes du tour guidé (#351).
//
// Chaque étape pointe sur un onglet (route) à afficher en arrière-plan
// pendant que l'overlay tooltip apparaît au-dessus. Le tour suit l'ordre
// naturel d'utilisation : Aujourd'hui → Officine → Scan → Partages → Fin.
//
// `target` désigne le widget à mettre en spotlight : le backdrop sombre
// est percé d'un trou autour du Rect résolu via `GlobalKey`. Les targets
// vivent dans `onboarding_targets.dart`.
import 'package:piloo/core/router/routes.dart';

enum TourTarget {
  none,
  scanFab,
  firstPriseCard,
  firstBoiteCard,
  perimeChip,
}

class OnboardingStep {
  const OnboardingStep({
    required this.tab,
    required this.title,
    required this.body,
    this.target = TourTarget.none,
  });

  /// RouteName.* du tab à mettre en arrière-plan pendant cette étape.
  /// null = pas de navigation forcée (utile pour la step finale).
  final String? tab;
  final String title;
  final String body;
  final TourTarget target;
}

const onboardingSteps = <OnboardingStep>[
  OnboardingStep(
    tab: RouteName.today,
    title: "Bienvenue dans Piloo",
    body:
        "Voici votre carnet médicaments. On commence par l'écran Aujourd'hui, "
        "qui liste vos prises du jour.",
  ),
  OnboardingStep(
    tab: RouteName.today,
    title: "Confirmer une prise",
    body:
        "Tape sur le rond gauche d'une prise pour la marquer comme faite. "
        "Long-press pour ouvrir le menu (sauter, reporter, modifier la dose).",
    target: TourTarget.firstPriseCard,
  ),
  OnboardingStep(
    tab: RouteName.officine,
    title: "Vos boîtes",
    body:
        "Toutes vos boîtes dans une seule vue. Tape une carte pour voir le "
        "stock restant, le lot et les actions rapides.",
    target: TourTarget.firstBoiteCard,
  ),
  OnboardingStep(
    tab: RouteName.officine,
    title: "Filtre Périmé",
    body:
        "Les boîtes périmées sont comptées ici. Tape pour ne voir qu'elles — "
        "pratique pour faire le tri régulièrement.",
    target: TourTarget.perimeChip,
  ),
  OnboardingStep(
    tab: RouteName.officine,
    title: "Scanner une nouvelle boîte",
    body:
        "Le bouton orange central reconnaît automatiquement les datamatrix "
        "des boîtes françaises. Pas besoin de saisir le nom — Piloo le "
        "récupère depuis la BDPM officielle.",
    target: TourTarget.scanFab,
  ),
  OnboardingStep(
    tab: RouteName.more,
    title: "Partager avec vos proches",
    body:
        "Depuis Plus → Mes officines, vous pouvez inviter un proche pour "
        "qu'il voie aussi votre carnet (utile pour un parent âgé suivi à "
        "distance).",
  ),
  OnboardingStep(
    tab: null,
    title: "Prêt à commencer",
    body:
        "C'est tout pour le tour. À vous de jouer : scannez votre première "
        "boîte et créez vos rappels. Vous pouvez relancer ce tour à tout "
        "moment depuis Plus → Aide.",
  ),
];
