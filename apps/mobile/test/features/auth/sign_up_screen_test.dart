// Widget tests pour A4 Inscription (#60).
// Vérifie le rendu fidèle à la maquette et la validation locale.
// L'intégration HTTP réelle (Better Auth) est testée côté apps/web —
// ici on s'assure juste que le formulaire affiche les bons éléments
// et que la validation locale bloque les soumissions invalides.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/storage/secure_storage.dart';
import 'package:piloo/features/auth/data/session_storage.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/auth/presentation/sign_up_screen.dart';

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
  group('SignUpScreen', () {
    testWidgets('affiche le titre + sous-titre + 2 boutons sociaux + form',
        (tester) async {
      await tester.pumpWidget(_harness(const SignUpScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Créons ton compte'), findsOneWidget);
      expect(
        find.text('Quelques infos et tu pourras scanner ta première boîte.'),
        findsOneWidget,
      );
      expect(find.text('Continuer avec Apple'), findsOneWidget);
      expect(find.text('Continuer avec Google'), findsOneWidget);
      expect(find.text('ou'), findsOneWidget);
      expect(find.text('PRÉNOM'), findsOneWidget);
      expect(find.text('NOM'), findsOneWidget);
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('MOT DE PASSE'), findsOneWidget);
      expect(find.text('Créer mon compte'), findsOneWidget);
      expect(find.textContaining('Déjà un compte'), findsOneWidget);
    });

    testWidgets('disclaimer "carnet de suivi personnel" visible', (tester) async {
      await tester.pumpWidget(_harness(const SignUpScreen()));
      await tester.pumpAndSettle();

      // Garde-fou non-négociable du CLAUDE.md : la mention "pas un dispositif
      // médical" doit apparaître à la création de compte.
      expect(
        find.textContaining('pas un dispositif médical'),
        findsOneWidget,
      );
    });

    testWidgets('valide localement : champs vides → erreur visible', (tester) async {
      await tester.pumpWidget(_harness(const SignUpScreen()));
      await tester.pumpAndSettle();

      // Le bouton peut être hors viewport selon la taille de test :
      // on s'assure qu'il est visible avant d'essayer de tapper.
      await tester.ensureVisible(find.text('Créer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer mon compte'));
      await tester.pumpAndSettle();

      expect(find.text('Prénom requis.'), findsOneWidget);
    });

    testWidgets('valide localement : password < 8 → erreur visible',
        (tester) async {
      await tester.pumpWidget(_harness(const SignUpScreen()));
      await tester.pumpAndSettle();

      // Remplit prénom/nom/email valides puis password trop court.
      await tester.enterText(find.byType(TextField).at(0), 'Maxime');
      await tester.enterText(find.byType(TextField).at(1), 'Durand');
      await tester.enterText(find.byType(TextField).at(2), 'maxime@piloo.fr');
      await tester.enterText(find.byType(TextField).at(3), 'short');
      await tester.pumpAndSettle();

      // Le bouton peut être hors viewport selon la taille de test :
      // on s'assure qu'il est visible avant d'essayer de tapper.
      await tester.ensureVisible(find.text('Créer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer mon compte'));
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe : 8 caractères minimum.'), findsOneWidget);
    });

    testWidgets('valide localement : CGU non acceptées → erreur visible',
        (tester) async {
      await tester.pumpWidget(_harness(const SignUpScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Maxime');
      await tester.enterText(find.byType(TextField).at(1), 'Durand');
      await tester.enterText(find.byType(TextField).at(2), 'maxime@piloo.fr');
      await tester.enterText(find.byType(TextField).at(3), 'pass-word-1234');
      await tester.pumpAndSettle();

      // Le bouton peut être hors viewport selon la taille de test :
      // on s'assure qu'il est visible avant d'essayer de tapper.
      await tester.ensureVisible(find.text('Créer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer mon compte'));
      await tester.pumpAndSettle();

      expect(find.text('Tu dois accepter les conditions.'), findsOneWidget);
    });
  });
}
