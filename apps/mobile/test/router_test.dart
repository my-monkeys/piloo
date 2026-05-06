// Tests du router (#45) : la config se construit, toutes les routes M1
// sont accessibles par leur path/nom typé, et les paramètres dynamiques
// arrivent bien jusqu'à l'écran.
//
// Depuis #58, la route `/` est SplashScreen (animations infinies +
// timer de redirect). On wrap avec un ProviderScope pour les
// dépendances Riverpod et on évite `pumpAndSettle` (les loader dots
// du splash bouclent forever).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/router/router.dart';
import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/storage/secure_storage.dart';
import 'package:piloo/features/auth/data/session_storage.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:go_router/go_router.dart';

Widget _wrap(GoRouterApp app) {
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        SessionStorage(InMemorySecureStorage()),
      ),
    ],
    child: app.build(),
  );
}

class GoRouterApp {
  GoRouterApp(this.router);
  final dynamic router;
  Widget build() => MaterialApp.router(routerConfig: router);
}

void main() {
  group('buildRouter', () {
    testWidgets('construit sans erreur et démarre sur /', (
      WidgetTester tester,
    ) async {
      final router = buildRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(_wrap(GoRouterApp(router)));
      // Pas de pumpAndSettle : les loader dots du splash bouclent.
      await tester.pump(const Duration(milliseconds: 50));

      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    });

    testWidgets('navigation vers chaque écran principal', (
      WidgetTester tester,
    ) async {
      final router = buildRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(_wrap(GoRouterApp(router)));
      // Pas de pumpAndSettle : les loader dots du splash bouclent.
      await tester.pump(const Duration(milliseconds: 50));

      // Routes simples (pas de paramètre)
      const flat = [
        RoutePath.welcome,
        RoutePath.accountType,
        RoutePath.signIn,
        RoutePath.signUp,
        RoutePath.verifyEmail,
        RoutePath.forgotPassword,
        RoutePath.resetPassword,
        RoutePath.legal,
        RoutePath.permissions,
        RoutePath.today,
        RoutePath.officine,
        RoutePath.more,
        RoutePath.scan,
        RoutePath.alertes,
        RoutePath.boiteAdd,
        RoutePath.ordonnances,
        RoutePath.ordonnanceCreate,
        RoutePath.ordonnanceOcr,
        RoutePath.officinesList,
        RoutePath.settings,
        RoutePath.settingsProfile,
        RoutePath.settingsNotifications,
        RoutePath.settingsHoraires,
        RoutePath.settingsSecurity,
        RoutePath.proDashboard,
      ];

      for (final path in flat) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          path,
          reason: 'go($path) doit aboutir au path $path',
        );
      }
    });

    testWidgets('routes paramétrées propagent le pathParameter', (
      WidgetTester tester,
    ) async {
      final router = buildRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(_wrap(GoRouterApp(router)));
      // Pas de pumpAndSettle : les loader dots du splash bouclent.
      await tester.pump(const Duration(milliseconds: 50));

      router.go(RoutePath.boiteDetail('abc-123'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/boites/abc-123',
      );
      expect(find.textContaining('abc-123'), findsOneWidget);

      router.go(RoutePath.medicamentInfo('3400930000019'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/medicaments/3400930000019',
      );
      expect(find.textContaining('3400930000019'), findsOneWidget);

      router.go(RoutePath.invitationAccept('tok-xyz'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/invitations/tok-xyz',
      );
      expect(find.textContaining('tok-xyz'), findsOneWidget);
    });

    test('shell route a 4 branches (today/officine/alertes/more)', () {
      // Vérification structurelle plutôt que par widget tree : plus
      // robuste vis-à-vis des transitions et GlobalKey du shell, et
      // documente l'ordre des onglets de la PilooTabBar.
      final router = buildRouter();
      addTearDown(router.dispose);

      final shellRoute = router.configuration.routes
          .whereType<StatefulShellRoute>()
          .single;
      expect(shellRoute.branches.length, 4);
      final branchPaths = shellRoute.branches
          .map((b) => (b.routes.first as GoRoute).path)
          .toList();
      expect(branchPaths, [
        RoutePath.today,
        RoutePath.officine,
        RoutePath.alertes,
        RoutePath.more,
      ]);
    });

    test('les noms de routes sont stables (pas de doublon)', () {
      // Sécurité : si quelqu'un duplique un nom de route on s'en aperçoit
      // au lancement plutôt qu'à un push runtime.
      const allNames = <String>{
        RouteName.splash,
        RouteName.welcome,
        RouteName.accountType,
        RouteName.signIn,
        RouteName.signUp,
        RouteName.verifyEmail,
        RouteName.forgotPassword,
        RouteName.resetPassword,
        RouteName.legal,
        RouteName.permissions,
        RouteName.today,
        RouteName.officine,
        RouteName.more,
        RouteName.scan,
        RouteName.alertes,
        RouteName.boiteAdd,
        RouteName.boiteDetail,
        RouteName.medicamentInfo,
        RouteName.ordonnances,
        RouteName.ordonnanceCreate,
        RouteName.ordonnanceDetail,
        RouteName.ordonnanceOcr,
        RouteName.officinesList,
        RouteName.officineSettings,
        RouteName.partages,
        RouteName.invitationAccept,
        RouteName.settings,
        RouteName.settingsProfile,
        RouteName.settingsNotifications,
        RouteName.settingsHoraires,
        RouteName.settingsSecurity,
        RouteName.proDashboard,
        RouteName.dev,
      };
      // 32 routes M1 + 1 dev cachée = 33 — si l'effectif baisse c'est
      // qu'on a un doublon.
      expect(allNames.length, 33);
    });
  });
}
