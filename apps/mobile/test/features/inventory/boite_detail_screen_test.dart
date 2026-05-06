// Widget tests pour Détail boîte (#98).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/inventory/presentation/boite_detail_screen.dart';

Widget _harness() {
  return const MaterialApp(home: BoiteDetailScreen(boiteId: 'abc-123'));
}

void main() {
  group('BoiteDetailScreen', () {
    testWidgets('rendu : header + hero + info grid + lien fiche + bottom',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Détail boîte'), findsOneWidget);

      // Hero
      expect(find.text('Doliprane 1000 mg'), findsOneWidget);
      expect(find.text('Paracétamol · comprimé pelliculé'), findsOneWidget);

      // Info grid
      expect(find.text('PÉREMPTION'), findsOneWidget);
      expect(find.text('03 / 2028'), findsOneWidget);
      expect(find.text('STOCK'), findsOneWidget);
      expect(find.text('8 comprimés'), findsOneWidget);
      expect(find.text('N° DE LOT'), findsOneWidget);
      expect(find.text('LOT42AB7'), findsOneWidget);
      expect(find.text('AJOUTÉE LE'), findsOneWidget);
      expect(find.text('15 mars'), findsOneWidget);

      // Lien fiche médicament
      expect(find.text('Voir la fiche médicament'), findsOneWidget);

      // Historique
      expect(find.text('HISTORIQUE'), findsOneWidget);
      expect(find.text('Stock ajusté — 8 comprimés'), findsOneWidget);

      // Bottom actions
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Marquer vide'), findsOneWidget);
    });
  });
}
