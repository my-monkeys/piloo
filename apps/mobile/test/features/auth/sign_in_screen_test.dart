// Widget tests pour A3 Connexion (#61). Vérifie le rendu fidèle à la
// maquette `6tsCm` et la validation locale.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/storage/secure_storage.dart';
import 'package:piloo/features/auth/data/session_storage.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/auth/presentation/sign_in_screen.dart';

Widget _harness(Widget child) {
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        SessionStorage(InMemorySecureStorage()),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('SignInScreen', () {
    testWidgets('rendu : Bon retour + form + lien mdp oublié + Se connecter',
        (tester) async {
      await tester.pumpWidget(_harness(const SignInScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Bon retour'), findsOneWidget);
      expect(find.text('Connecte-toi pour accéder à tes officines.'), findsOneWidget);
      expect(find.text('Continuer avec Apple'), findsOneWidget);
      expect(find.text('Continuer avec Google'), findsOneWidget);
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('MOT DE PASSE'), findsOneWidget);
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.textContaining('Pas encore de compte'), findsOneWidget);
      expect(find.text("S'inscrire"), findsOneWidget);
    });

    testWidgets('valide : email vide → erreur via toast', (tester) async {
      await tester.pumpWidget(_harness(const SignInScreen()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Se connecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Email invalide.'), findsOneWidget);
    });

    testWidgets('valide : password vide → erreur via toast', (tester) async {
      await tester.pumpWidget(_harness(const SignInScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'maxime@piloo.fr');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Se connecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe requis.'), findsOneWidget);
    });
  });
}
