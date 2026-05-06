// Widget tests pour Fiche médicament (#99).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/inventory/presentation/medicament_info_screen.dart';

Widget _harness() {
  return const MaterialApp(home: MedicamentInfoScreen(cip13: '3400934857188'));
}

void main() {
  group('MedicamentInfoScreen', () {
    testWidgets('rendu : header + hero + tags + table + résumé IA + notice',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Fiche médicament'), findsOneWidget);

      // Hero
      expect(find.text('Doliprane 1000 mg'), findsOneWidget);
      expect(find.text('Comprimé pelliculé'), findsOneWidget);
      expect(find.text('Non listé'), findsOneWidget);
      expect(find.text('Remboursé 65%'), findsOneWidget);

      // Table
      expect(find.text('Principe actif'), findsOneWidget);
      expect(find.text('Paracétamol'), findsOneWidget);
      expect(find.text('Laboratoire'), findsOneWidget);
      expect(find.text('Sanofi'), findsOneWidget);
      expect(find.text('CIP13'), findsOneWidget);
      expect(find.text('3400934857188'), findsOneWidget);

      // Résumé IA + footer "généré auto"
      expect(find.text('À QUOI ÇA SERT'), findsOneWidget);
      expect(
        find.textContaining('soulager la fièvre'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Résumé généré automatiquement'),
        findsOneWidget,
      );

      // Notice + disclaimer
      expect(find.text('Voir la notice officielle'), findsOneWidget);
      expect(
        find.textContaining('à titre indicatif'),
        findsOneWidget,
      );
    });
  });
}
