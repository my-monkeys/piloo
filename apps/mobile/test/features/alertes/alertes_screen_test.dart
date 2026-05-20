// Widget tests pour Alertes (#149).
//
// alertesProvider est overridé avec une liste vide → empty state.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/features/alertes/data/alertes_provider.dart';
import 'package:piloo/features/alertes/presentation/alertes_screen.dart';

Widget _harness() {
  return ProviderScope(
    overrides: [
      alertesProvider.overrideWith((_) async => const <api.Alerte>[]),
    ],
    child: const MaterialApp(home: AlertesScreen()),
  );
}

void main() {
  group('AlertesScreen', () {
    testWidgets('rendu : header + empty state si aucune alerte',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Alertes'), findsOneWidget);
      expect(find.text('Aucune alerte'), findsOneWidget);
    });
  });
}
