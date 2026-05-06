// Tests du router (#45) : la config se construit, toutes les routes M1
// sont accessibles par leur path/nom typé, et les paramètres dynamiques
// arrivent bien jusqu'à l'écran.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/router/router.dart';
import 'package:piloo/core/router/routes.dart';

void main() {
  group('buildRouter', () {
    testWidgets('construit sans erreur et démarre sur /', (
      WidgetTester tester,
    ) async {
      final router = buildRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    });

    testWidgets('navigation vers chaque écran principal', (
      WidgetTester tester,
    ) async {
      final router = buildRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

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

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

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

    testWidgets('shell route préserve la tab bar sur today/officine/more', (
      WidgetTester tester,
    ) async {
      final router = buildRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      router.go(RoutePath.today);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);

      router.go(RoutePath.officine);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);

      router.go(RoutePath.more);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
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
      };
      // 32 routes M1 — si l'effectif baisse c'est qu'on a un doublon.
      expect(allNames.length, 32);
    });
  });
}
