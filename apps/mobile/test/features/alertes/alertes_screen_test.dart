// Widget tests pour Alertes (#149).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/alertes/presentation/alertes_screen.dart';

Widget _harness() {
  return const MaterialApp(home: AlertesScreen());
}

void main() {
  group('AlertesScreen', () {
    testWidgets('rendu : header + 2 groupes + 5 cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Alertes'), findsOneWidget);
      expect(find.text('Tout lire'), findsOneWidget);

      expect(find.text("AUJOURD'HUI"), findsOneWidget);
      expect(find.text('CETTE SEMAINE'), findsOneWidget);

      expect(find.text('Prise oubliée — Ramipril 5 mg'), findsOneWidget);
      expect(find.text('Péremption proche — Kardegic 75 mg'), findsOneWidget);
      expect(find.text('Stock bas — Metformine 500 mg'), findsOneWidget);
      expect(find.text('Manque signalé par Papa'), findsOneWidget);
      expect(find.text('Partage accepté'), findsOneWidget);
    });
  });
}
