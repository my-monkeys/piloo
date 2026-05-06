// Configuration du router (#45). Couvre toutes les routes M1 listées dans
// docs/ui-ux-guidelines.md §"Écrans mobile".
//
// Architecture :
// - Routes auth/onboarding : top-level (pas de tab bar).
// - Coquille principale : `StatefulShellRoute.indexedStack` pour la tab bar
//   3 onglets (Aujourd'hui / Officine / Plus). Préserve l'état de chaque
//   onglet en background.
// - Actions globales (scan, alertes) : top-level, push par-dessus la
//   coquille.
// - Sous-écrans (détails boîte, ordonnance…) : push avec retour à la
//   tab bar courante.
//
// `redirect` : centralisé ici, branchera l'auth en #58 (A1 Splash). Pour
// l'instant la racine `/` mène au splash placeholder.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:piloo/features/auth/presentation/account_type_screen.dart';
import 'package:piloo/features/auth/presentation/forgot_password_screen.dart';
import 'package:piloo/features/auth/presentation/sign_in_screen.dart';
import 'package:piloo/features/auth/presentation/sign_up_screen.dart';
import 'package:piloo/features/auth/presentation/splash_screen.dart';
import 'package:piloo/features/auth/presentation/verify_email_screen.dart';

import 'dev_home_screen.dart';
import 'placeholder_screen.dart';
import 'routes.dart';

GoRouter buildRouter() {
  // Override dev-only : permet de booter directement sur n'importe quelle
  // route via `flutter run --dart-define=PILOO_BOOT_ROUTE=/sign-in`. Si vide,
  // on tombe sur le splash normal. Pratique pour la review design en
  // simulateur, vu la difficulté d'enchaîner des taps rapides via xcrun.
  const bootRouteOverride = String.fromEnvironment('PILOO_BOOT_ROUTE');
  final initialLocation =
      bootRouteOverride.isNotEmpty ? bootRouteOverride : RoutePath.splash;

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    routes: [
      // Onboarding & auth (top-level, pas de tab bar)
      GoRoute(
        path: RoutePath.splash,
        name: RouteName.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      // Route dev cachée : 5 taps sur le logo du splash y mènent.
      // Permet à l'équipe design de naviguer entre les écrans M1 tant
      // qu'ils ne sont pas tous implémentés.
      GoRoute(
        path: RoutePath.dev,
        name: RouteName.dev,
        builder: (_, _) => const DevHomeScreen(),
      ),
      GoRoute(
        path: RoutePath.welcome,
        name: RouteName.welcome,
        builder: (_, _) =>
            PlaceholderScreen(title: 'Welcome', subtitle: 'O1 (#66)'),
      ),
      GoRoute(
        path: RoutePath.accountType,
        name: RouteName.accountType,
        builder: (_, _) => const AccountTypeScreen(),
      ),
      GoRoute(
        path: RoutePath.signIn,
        name: RouteName.signIn,
        builder: (_, _) => const SignInScreen(),
      ),
      GoRoute(
        path: RoutePath.signUp,
        name: RouteName.signUp,
        // `typeCompte` est passé via `extra` (chaîne) — par défaut
        // 'particulier' tant que l'écran A2 (#59) n'est pas en place.
        builder: (_, state) {
          final extra = state.extra;
          final typeCompte = extra is String ? extra : 'particulier';
          return SignUpScreen(typeCompte: typeCompte);
        },
      ),
      GoRoute(
        path: RoutePath.verifyEmail,
        name: RouteName.verifyEmail,
        // L'email est passé via state.extra (depuis SignUp ou SignIn).
        // Default placeholder utilisé en review design.
        builder: (_, state) {
          final extra = state.extra;
          final email = extra is String ? extra : 'votre@email.fr';
          return VerifyEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: RoutePath.forgotPassword,
        name: RouteName.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePath.resetPassword,
        name: RouteName.resetPassword,
        builder: (_, _) =>
            PlaceholderScreen(title: 'Reset password', subtitle: 'A6 (#63)'),
      ),
      GoRoute(
        path: RoutePath.legal,
        name: RouteName.legal,
        builder: (_, _) => PlaceholderScreen(
          title: 'Mentions légales',
          subtitle: 'O2 (#67) — disclaimer carnet de suivi',
        ),
      ),
      GoRoute(
        path: RoutePath.permissions,
        name: RouteName.permissions,
        builder: (_, _) => PlaceholderScreen(
          title: 'Permissions',
          subtitle: 'O3 (#68) — caméra + notifs',
        ),
      ),

      // Tab bar principale (Aujourd'hui / Officine / Plus)
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => _MainShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePath.today,
                name: RouteName.today,
                builder: (_, _) => PlaceholderScreen(
                  title: 'Aujourd\'hui',
                  subtitle: 'Timeline de prises du jour',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePath.officine,
                name: RouteName.officine,
                builder: (_, _) => PlaceholderScreen(
                  title: 'Officine',
                  subtitle: 'Inventaire',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePath.more,
                name: RouteName.more,
                builder: (_, _) =>
                    PlaceholderScreen(title: 'Plus', subtitle: 'Paramètres'),
              ),
            ],
          ),
        ],
      ),

      // Actions globales (push par-dessus)
      GoRoute(
        path: RoutePath.scan,
        name: RouteName.scan,
        builder: (_, _) =>
            PlaceholderScreen(title: 'Scan', subtitle: 'DataMatrix (#80)'),
      ),
      GoRoute(
        path: RoutePath.alertes,
        name: RouteName.alertes,
        builder: (_, _) =>
            PlaceholderScreen(title: 'Alertes', subtitle: 'Liste'),
      ),

      // Boîtes
      GoRoute(
        path: RoutePath.boiteAdd,
        name: RouteName.boiteAdd,
        builder: (_, _) =>
            PlaceholderScreen(title: 'Nouvelle boîte', subtitle: 'Post-scan (#89)'),
      ),
      GoRoute(
        path: '/boites/:boiteId',
        name: RouteName.boiteDetail,
        builder: (_, state) => PlaceholderScreen(
          title: 'Détail boîte',
          params: {'boiteId': state.pathParameters['boiteId'] ?? ''},
        ),
      ),
      GoRoute(
        path: '/medicaments/:cip13',
        name: RouteName.medicamentInfo,
        builder: (_, state) => PlaceholderScreen(
          title: 'Fiche médicament',
          params: {'cip13': state.pathParameters['cip13'] ?? ''},
        ),
      ),

      // Ordonnances
      GoRoute(
        path: RoutePath.ordonnances,
        name: RouteName.ordonnances,
        builder: (_, _) =>
            PlaceholderScreen(title: 'Ordonnances', subtitle: 'Liste'),
      ),
      GoRoute(
        path: RoutePath.ordonnanceCreate,
        name: RouteName.ordonnanceCreate,
        builder: (_, _) =>
            PlaceholderScreen(title: 'Nouvelle ordonnance', subtitle: 'Saisie'),
      ),
      GoRoute(
        path: RoutePath.ordonnanceOcr,
        name: RouteName.ordonnanceOcr,
        builder: (_, _) =>
            PlaceholderScreen(title: 'OCR ordonnance', subtitle: 'v2 MVP'),
      ),
      GoRoute(
        path: '/ordonnances/:ordonnanceId',
        name: RouteName.ordonnanceDetail,
        builder: (_, state) => PlaceholderScreen(
          title: 'Détail ordonnance',
          params: {
            'ordonnanceId': state.pathParameters['ordonnanceId'] ?? '',
          },
        ),
      ),

      // Officines & partages
      GoRoute(
        path: RoutePath.officinesList,
        name: RouteName.officinesList,
        builder: (_, _) => PlaceholderScreen(
          title: 'Mes officines',
          subtitle: 'S1 (#72)',
        ),
      ),
      GoRoute(
        path: '/officines/:officineId/settings',
        name: RouteName.officineSettings,
        builder: (_, state) => PlaceholderScreen(
          title: 'Réglages officine',
          params: {'officineId': state.pathParameters['officineId'] ?? ''},
        ),
      ),
      GoRoute(
        path: '/officines/:officineId/partages',
        name: RouteName.partages,
        builder: (_, state) => PlaceholderScreen(
          title: 'Partages',
          params: {'officineId': state.pathParameters['officineId'] ?? ''},
        ),
      ),
      GoRoute(
        path: '/invitations/:token',
        name: RouteName.invitationAccept,
        builder: (_, state) => PlaceholderScreen(
          title: 'Invitation',
          params: {'token': state.pathParameters['token'] ?? ''},
        ),
      ),

      // Settings
      GoRoute(
        path: RoutePath.settings,
        name: RouteName.settings,
        builder: (_, _) =>
            PlaceholderScreen(title: 'Paramètres', subtitle: 'Index'),
      ),
      GoRoute(
        path: RoutePath.settingsProfile,
        name: RouteName.settingsProfile,
        builder: (_, _) => PlaceholderScreen(title: 'Profil'),
      ),
      GoRoute(
        path: RoutePath.settingsNotifications,
        name: RouteName.settingsNotifications,
        builder: (_, _) => PlaceholderScreen(title: 'Notifications'),
      ),
      GoRoute(
        path: RoutePath.settingsHoraires,
        name: RouteName.settingsHoraires,
        builder: (_, _) => PlaceholderScreen(
          title: 'Horaires par défaut',
          subtitle: 'matin/midi/soir/coucher (#156)',
        ),
      ),
      GoRoute(
        path: RoutePath.settingsSecurity,
        name: RouteName.settingsSecurity,
        builder: (_, _) =>
            PlaceholderScreen(title: 'Sécurité', subtitle: '2FA (#157)'),
      ),

      // Vue pro
      GoRoute(
        path: RoutePath.proDashboard,
        name: RouteName.proDashboard,
        builder: (_, _) => PlaceholderScreen(
          title: 'Vue pro',
          subtitle: 'Dashboard patients suivis',
        ),
      ),
    ],
  );
}

class _MainShell extends StatelessWidget {
  const _MainShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Aujourd\'hui',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'Officine',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Plus',
          ),
        ],
      ),
    );
  }
}
