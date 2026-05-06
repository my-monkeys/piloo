// Widget tests pour A5 Vérification email (#62).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/features/auth/presentation/verify_email_screen.dart';

Widget _harness({String email = 'test@piloo.fr'}) {
  return MaterialApp(home: VerifyEmailScreen(email: email));
}

void main() {
  group('VerifyEmailScreen', () {
    testWidgets('rendu : icône + titre + email pill + help + bouton + countdown',
        (tester) async {
      await tester.pumpWidget(_harness(email: 'maxime@exemple.fr'));
      // Pump 1 frame seulement (countdown est en cours, pas de
      // pumpAndSettle car le ticker boucle).
      await tester.pump();

      expect(find.byIcon(PhosphorIconsFill.envelopeSimple), findsOneWidget);
      expect(find.text('Vérifie ton email'), findsOneWidget);
      expect(find.text("On vient d'envoyer un lien de confirmation à"),
          findsOneWidget);
      expect(find.text('maxime@exemple.fr'), findsOneWidget);
      expect(find.textContaining("Ouvre l'email"), findsOneWidget);
      expect(find.text("J'ai cliqué sur le lien"), findsOneWidget);
      expect(find.text('Pas reçu ?'), findsOneWidget);
      // Countdown initial à 60s
      expect(find.text('Renvoyer dans 60s'), findsOneWidget);
    });

    testWidgets('countdown décompte chaque seconde', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();

      expect(find.text('Renvoyer dans 60s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Renvoyer dans 59s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Renvoyer dans 54s'), findsOneWidget);
    });

    testWidgets('après 60s : "Renvoyer" devient cliquable', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();

      await tester.pump(const Duration(seconds: 60));
      expect(find.text('Renvoyer'), findsOneWidget);
      expect(find.textContaining('Renvoyer dans'), findsNothing);
    });
  });
}
