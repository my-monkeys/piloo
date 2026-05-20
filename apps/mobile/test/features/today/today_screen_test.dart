// Widget tests pour Aujourd'hui (#115).
//
// Les sections du Today sont maintenant data-driven via API. Avec un
// override `activeOfficineProvider = null` on déclenche le chemin
// "aucune officine" → AsyncValue.data([]) → empty state.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/features/officines/data/active_officine_provider.dart';
import 'package:piloo/features/today/presentation/today_screen.dart';

class _NoActiveOfficineNotifier extends ActiveOfficineNotifier {
  @override
  Future<api.Officine?> build() async => null;
}

Widget _harness() {
  return ProviderScope(
    overrides: [
      activeOfficineProvider.overrideWith(_NoActiveOfficineNotifier.new),
    ],
    child: const MaterialApp(home: TodayScreen()),
  );
}

void main() {
  group('TodayScreen', () {
    testWidgets('rendu : header + day picker + empty state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text("Aujourd'hui"), findsOneWidget);
      expect(find.text("Rien de prévu aujourd'hui"), findsOneWidget);
    });
  });
}
