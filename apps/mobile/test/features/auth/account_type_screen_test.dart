// Widget tests pour A2 Type compte (#59).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/features/auth/presentation/account_type_screen.dart';

Widget _harness() {
  return const MaterialApp(home: AccountTypeScreen());
}

void main() {
  group('AccountTypeScreen', () {
    testWidgets('rendu : titre + 2 cards + bouton', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Tu utilises Piloo pour…'), findsOneWidget);
      expect(find.text('Particulier'), findsOneWidget);
      expect(find.text('Mon officine familiale et celle de mes proches'),
          findsOneWidget);
      expect(find.text('Pro de santé'), findsOneWidget);
      expect(find.text('IDEL, aide-soignant, aidant à domicile, SSIAD'),
          findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
    });

    testWidgets('par défaut "particulier" est sélectionné (check visible)',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // Le check-bold n'apparaît que sur la card sélectionnée.
      expect(find.byIcon(PhosphorIconsBold.check), findsOneWidget);
      // Le house-fill (icône particulier) est dans la card sélectionnée
      // donc visible avec un fond primary-soft.
      expect(find.byIcon(PhosphorIconsFill.house), findsOneWidget);
    });

    testWidgets('tap sur card pro → sélection bascule', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pro de santé'));
      await tester.pumpAndSettle();

      // Le check-bold est maintenant sur la card pro.
      expect(find.byIcon(PhosphorIconsBold.check), findsOneWidget);
    });
  });
}
