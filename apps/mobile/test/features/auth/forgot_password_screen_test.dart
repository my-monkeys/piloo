// Widget tests A6 Mot de passe oublié (#63).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/features/auth/presentation/forgot_password_screen.dart';

Widget _harness() {
  return const MaterialApp(home: ForgotPasswordScreen());
}

void main() {
  group('ForgotPasswordScreen', () {
    testWidgets('rendu : icône clé + titre + form + boutons', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsFill.key), findsOneWidget);
      expect(find.text('Mot de passe oublié'), findsOneWidget);
      expect(
        find.textContaining("on t'envoie un lien"),
        findsOneWidget,
      );
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('Recevoir le lien'), findsOneWidget);
      expect(find.text('Retour à la connexion'), findsOneWidget);
    });

    testWidgets('email vide → toast "Email invalide."', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Recevoir le lien'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recevoir le lien'));
      await tester.pumpAndSettle();

      expect(find.text('Email invalide.'), findsOneWidget);
    });
  });
}
