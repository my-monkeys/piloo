// Étapes du tour guidé (#351).
//
// Chaque étape pointe sur un onglet (route) à afficher en arrière-plan
// pendant que l'overlay tooltip apparaît au-dessus. Le tour suit l'ordre
// naturel d'utilisation : Aujourd'hui → Officine → Scan → Partages → Fin.
import 'package:piloo/core/router/routes.dart';

class OnboardingStep {
  const OnboardingStep({
    required this.tab,
    required this.title,
    required this.body,
  });

  /// RouteName.* du tab à mettre en arrière-plan pendant cette étape.
  /// null = pas de navigation forcée (utile pour la step finale).
  final String? tab;
  final String title;
  final String body;
}

const onboardingSteps = <OnboardingStep>[
  OnboardingStep(
    tab: RouteName.today,
    title: "Bienvenue dans Piloo",
    body:
        "Voici votre carnet médicaments. On commence par l'écran Aujourd'hui, "
        "qui liste vos prises du jour. Tape sur le rond gauche pour confirmer "
        "qu'une prise a été faite.",
  ),
  OnboardingStep(
    tab: RouteName.officine,
    title: "Votre officine",
    body:
        "Toutes vos boîtes dans une seule vue. Les boîtes périmées sont "
        "signalées en rouge, et celles en stock bas en orange. Tape une "
        "boîte pour ouvrir les actions rapides.",
  ),
  OnboardingStep(
    tab: RouteName.officine,
    title: "Scanner une nouvelle boîte",
    body:
        "Le bouton scanner central (orange) reconnaît automatiquement les "
        "datamatrix sur les boîtes françaises. Pas besoin de saisir le nom — "
        "Piloo le récupère depuis la BDPM officielle.",
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
