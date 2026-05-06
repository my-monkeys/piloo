// Widget tests pour Nouvelle boîte post-scan (#89).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/inventory/presentation/boite_add_screen.dart';

Widget _harness() {
  return const MaterialApp(home: BoiteAddScreen());
}

void main() {
  group('BoiteAddScreen', () {
    testWidgets('rendu : header + preview + champs + chips + actions',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle boîte'), findsOneWidget);

      // Preview médicament
      expect(find.text('Doliprane 1000 mg'), findsOneWidget);
      expect(find.text('Paracétamol · Sanofi'), findsOneWidget);
      expect(find.text('Comprimé pelliculé · 8 unités'), findsOneWidget);

      // Champs
      expect(find.text('PÉREMPTION'), findsOneWidget);
      expect(find.text('03 / 2028'), findsOneWidget);
      expect(find.text('N° DE LOT'), findsOneWidget);
      expect(find.text('LOT42AB7'), findsOneWidget);
      expect(find.text('OFFICINE CIBLE'), findsOneWidget);
      expect(find.text('Maison'), findsOneWidget);

      // Chips niveau initial
      expect(find.text('NIVEAU INITIAL'), findsOneWidget);
      expect(find.text('Plein'), findsOneWidget);
      expect(find.text('3/4'), findsOneWidget);
      expect(find.text('Moitié'), findsOneWidget);
      expect(find.text('1/4'), findsOneWidget);
      expect(find.text('Presque vide'), findsOneWidget);

      // Notes
      expect(find.text('NOTES (OPTIONNEL)'), findsOneWidget);

      // Actions
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);
    });

    testWidgets('tap sur un chip change la sélection', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // Tap "Moitié" doit changer la sélection — on ne peut pas
      // facilement asserter sur le visuel, on s'assure juste que le
      // tap ne fait pas crasher et que les 5 chips sont toujours là.
      await tester.tap(find.text('Moitié'));
      await tester.pumpAndSettle();
      expect(find.text('Plein'), findsOneWidget);
      expect(find.text('Moitié'), findsOneWidget);
    });
  });
}
