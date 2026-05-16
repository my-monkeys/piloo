// Tests SplashScreen (#58).
// Couvre :
//  - rendu (logo + wordmark + tagline + loader dots)
//  - redirection vers /welcome quand pas de session
//  - redirection vers /today quand session présente
//  - easter egg : 5 taps sur le logo → /_dev
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/router/router.dart';
import 'package:piloo/core/storage/secure_storage.dart';
import 'package:piloo/features/auth/data/session.dart';
import 'package:piloo/features/auth/data/session_storage.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';

const _seed = Session(
  token: 'tok-1',
  userId: 'user-1',
  email: 'a@piloo.fr',
  name: 'Alice Doe',
);

Widget _appWith({SessionStorage? storage}) {
  final router = buildRouter();
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        storage ?? SessionStorage(InMemorySecureStorage()),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('SplashScreen', () {
    testWidgets('rendu : logo + wordmark + tagline + dots', (tester) async {
      await tester.pumpWidget(_appWith());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.image(const AssetImage('assets/branding/app-icon.png')), findsOneWidget);
      expect(find.text('pil'), findsOneWidget);
      expect(find.text('oo'), findsOneWidget);
      expect(find.text('Le carnet numérique de médicaments'), findsOneWidget);

      // Drain : laisse le redirect timer expirer avant la fin du test.
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
    });

    testWidgets('sans session : redirige vers /welcome après le délai',
        (tester) async {
      await tester.pumpWidget(_appWith());
      // Avance le temps au-delà du délai mini de splash (1.2s)
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      // Depuis #66, /welcome affiche WelcomeScreen avec une 1ère slide
      // "Scanne, c'est tout". On vérifie ce marqueur + l'absence du
      // splash pour confirmer le redirect.
      expect(find.text("Scanne, c'est tout"), findsOneWidget);
      expect(find.image(const AssetImage('assets/branding/app-icon.png')), findsNothing);
    });

    testWidgets('avec session : redirige vers /today après le délai',
        (tester) async {
      final storage = SessionStorage(InMemorySecureStorage());
      await storage.write(_seed);

      await tester.pumpWidget(_appWith(storage: storage));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      expect(find.text("Aujourd'hui"), findsAtLeastNWidgets(1));
      expect(find.image(const AssetImage('assets/branding/app-icon.png')), findsNothing);
    });

    testWidgets('easter egg : 5 taps sur le logo poussent vers /_dev',
        (tester) async {
      await tester.pumpWidget(_appWith());
      await tester.pump(const Duration(milliseconds: 100));

      final logo = find.image(const AssetImage('assets/branding/app-icon.png'));
      // 5 taps rapides — le 5e doit annuler le redirect timer ET pousser
      // /_dev. Sinon le redirect auto vers /welcome aurait pu déclencher
      // avant qu'on arrive à 5.
      for (var i = 0; i < 5; i++) {
        await tester.tap(logo);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(find.text('Piloo — Dev menu'), findsOneWidget);
    });
  });
}
