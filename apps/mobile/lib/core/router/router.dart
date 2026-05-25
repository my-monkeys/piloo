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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:piloo/features/auth/presentation/account_type_screen.dart';
import 'package:piloo/features/auth/presentation/forgot_password_screen.dart';
import 'package:piloo/features/auth/presentation/legal_screen.dart';
import 'package:piloo/features/auth/presentation/permissions_screen.dart';
import 'package:piloo/features/alertes/presentation/alertes_screen.dart';
import 'package:piloo/features/auth/presentation/sign_in_screen.dart';
import 'package:piloo/features/inventory/presentation/boite_add_screen.dart';
import 'package:piloo/features/inventory/presentation/boite_detail_screen.dart';
import 'package:piloo/features/inventory/presentation/medicament_info_screen.dart';
import 'package:piloo/features/inventory/presentation/quick_actions_demo_screen.dart';
import 'package:piloo/features/more/presentation/more_screen.dart';
import 'package:piloo/features/officine/presentation/officine_screen.dart';
import 'package:piloo/features/officines/presentation/officines_list_screen.dart';
import 'package:piloo/features/ordonnances/presentation/ordonnance_create_screen.dart';
import 'package:piloo/features/ordonnances/presentation/ordonnance_detail_screen.dart';
import 'package:piloo/features/ordonnances/presentation/ordonnances_list_screen.dart';
import 'package:piloo/features/partages/presentation/invitation_accept_screen.dart';
import 'package:piloo/features/partages/presentation/invite_screen.dart';
import 'package:piloo/features/partages/presentation/partages_screen.dart';
import 'package:piloo/features/scan/presentation/scan_screen.dart';
import 'package:piloo/features/settings/presentation/horaires_screen.dart';
import 'package:piloo/features/settings/presentation/notifications_screen.dart';
import 'package:piloo/features/settings/presentation/profile_screen.dart';
import 'package:piloo/features/settings/presentation/bdpm_status_screen.dart';
import 'package:piloo/features/settings/presentation/security_screen.dart';
import 'package:piloo/features/today/presentation/today_screen.dart';
import 'package:piloo/shared/widgets/piloo_scan_fab.dart';
import 'package:piloo/shared/widgets/piloo_tab_bar.dart';
import 'package:piloo/shared/widgets/sync_pending_badge.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:piloo/features/auth/presentation/sign_up_screen.dart';
import 'package:piloo/features/auth/presentation/splash_screen.dart';
import 'package:piloo/features/auth/presentation/verify_email_screen.dart';
import 'package:piloo/features/auth/presentation/welcome_screen.dart';

import 'dev_home_screen.dart';
import 'placeholder_screen.dart';
import 'routes.dart';

/// Provider du router courant — override dans `app.dart` après
/// l'instanciation `buildRouter()`. Permet à n'importe quel widget
/// (y compris hors du Navigator, type overlays au niveau Material
/// App.builder) de pousser une route via `ref.read(routerProvider)
/// .goNamed(...)`.
final routerProvider = Provider<GoRouter>((ref) {
  throw UnimplementedError(
    'routerProvider must be overridden in app.dart after buildRouter().',
  );
});

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
      // Routes dev pour reviewer des composants non rattachés à un
      // écran principal (sheets, modales, etc.).
      GoRoute(
        path: '/_dev/quick-actions',
        builder: (_, _) => const QuickActionsDemoScreen(),
      ),
      GoRoute(
        path: RoutePath.welcome,
        name: RouteName.welcome,
        builder: (_, _) => const WelcomeScreen(),
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
        builder: (_, _) => const LegalScreen(),
      ),
      GoRoute(
        path: RoutePath.permissions,
        name: RouteName.permissions,
        builder: (_, _) => const PermissionsScreen(),
      ),

      // Tab bar principale Pill5 — Aujourd'hui / Officine / Alertes / Plus
      // (Alertes est un onglet, pas un push global, pour matcher la
      // maquette `AtFMv`).
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => _MainShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePath.today,
                name: RouteName.today,
                builder: (_, _) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePath.officine,
                name: RouteName.officine,
                builder: (_, _) => const OfficineScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePath.alertes,
                name: RouteName.alertes,
                builder: (_, _) => const AlertesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePath.more,
                name: RouteName.more,
                builder: (_, _) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),

      // Action globale Scan (push par-dessus la coquille)
      GoRoute(
        path: RoutePath.scan,
        name: RouteName.scan,
        builder: (_, _) => const ScanScreen(),
      ),

      // Boîtes
      GoRoute(
        path: RoutePath.boiteAdd,
        name: RouteName.boiteAdd,
        builder: (_, _) => const BoiteAddScreen(),
      ),
      GoRoute(
        path: '/boites/:boiteId',
        name: RouteName.boiteDetail,
        builder: (_, state) => BoiteDetailScreen(
          boiteId: state.pathParameters['boiteId'],
        ),
      ),
      GoRoute(
        path: '/medicaments/:cip13',
        name: RouteName.medicamentInfo,
        builder: (_, state) => MedicamentInfoScreen(
          cip13: state.pathParameters['cip13'],
        ),
      ),

      // Ordonnances
      GoRoute(
        path: RoutePath.ordonnances,
        name: RouteName.ordonnances,
        builder: (_, _) => const OrdonnancesListScreen(),
      ),
      GoRoute(
        path: RoutePath.ordonnanceCreate,
        name: RouteName.ordonnanceCreate,
        builder: (_, _) => const OrdonnanceCreateScreen(),
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
        builder: (_, state) => OrdonnanceDetailScreen(
          ordonnanceId: state.pathParameters['ordonnanceId'] ?? '',
        ),
      ),

      // Officines & partages
      GoRoute(
        path: RoutePath.officinesList,
        name: RouteName.officinesList,
        builder: (_, _) => const OfficinesListScreen(),
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
        builder: (_, state) => PartagesScreen(
          officineId: state.pathParameters['officineId'],
        ),
      ),
      GoRoute(
        path: '/officines/:officineId/invite',
        name: RouteName.invite,
        builder: (_, state) => InviteScreen(
          officineId: state.pathParameters['officineId'],
        ),
      ),
      GoRoute(
        path: '/invitations/:token',
        name: RouteName.invitationAccept,
        builder: (_, state) => InvitationAcceptScreen(
          token: state.pathParameters['token'],
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
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: RoutePath.settingsNotifications,
        name: RouteName.settingsNotifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePath.settingsHoraires,
        name: RouteName.settingsHoraires,
        builder: (_, _) => const HorairesScreen(),
      ),
      GoRoute(
        path: RoutePath.settingsSecurity,
        name: RouteName.settingsSecurity,
        builder: (_, _) => const SecurityScreen(),
      ),
      GoRoute(
        path: RoutePath.settingsBdpm,
        name: RouteName.settingsBdpm,
        builder: (_, _) => const BdpmStatusScreen(),
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

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  static const _tabs = [
    PilooTabItem(icon: PhosphorIconsFill.sunHorizon, label: 'AUJ.'),
    PilooTabItem(icon: PhosphorIconsRegular.firstAidKit, label: 'OFFICINE'),
    PilooTabItem(icon: PhosphorIconsRegular.bell, label: 'ALERTES'),
    PilooTabItem(icon: PhosphorIconsRegular.dotsThreeCircle, label: 'PLUS'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F3),
      // extendBody pour que la zone derrière la pilule soit transparente
      // (sinon le scroll content est coupé sous la tab bar).
      extendBody: true,
      // Ne resize pas le shell quand le clavier monte : sinon le FAB
      // Scan (centerDocked) remonte avec la tab bar et l'user le voit
      // bouger pendant qu'il tape (retour user 2026-05-23). Les écrans
      // qui ont des TextField doivent gérer leur propre scroll via
      // MediaQuery.viewInsets.bottom (cas des sheets / form scrollables).
      resizeToAvoidBottomInset: false,
      // Badge sync au top — `SizedBox.shrink()` quand pending = 0, donc
      // n'affecte pas le layout normal (#95).
      body: Column(
        children: [
          const SyncPendingBadge(),
          Expanded(child: widget.shell),
        ],
      ),
      bottomNavigationBar: PilooTabBar(
        items: _tabs,
        currentIndex: widget.shell.currentIndex,
        onTap: (i) => widget.shell
            .goBranch(i, initialLocation: i == widget.shell.currentIndex),
      ),
      floatingActionButton: PilooScanFab(
        onTap: () => GoRouter.of(context).goNamed(RouteName.scan),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
