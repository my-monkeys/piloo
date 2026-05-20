// Widget tests pour Officine inventaire (#87).
//
// Le mock fallback `_all` a été retiré (commit cleanup mocks). Sans
// officine active + sans boîte, l'écran affiche un empty state.
// On override activeOfficineProvider pour forcer le chemin "pas
// d'officine" → liste vide → _EmptyOfficine.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/core/storage/secure_storage.dart';
import 'package:piloo/features/auth/data/session_storage.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/officine/presentation/officine_screen.dart';
import 'package:piloo/features/officines/data/active_officine_provider.dart';

class _NoActiveOfficineNotifier extends ActiveOfficineNotifier {
  @override
  Future<api.Officine?> build() async => null;
}

Widget _harness() {
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        SessionStorage(InMemorySecureStorage()),
      ),
      activeOfficineProvider.overrideWith(_NoActiveOfficineNotifier.new),
    ],
    child: const MaterialApp(home: OfficineScreen()),
  );
}

void main() {
  group('OfficineScreen', () {
    testWidgets('rendu : header + empty state quand pas d\'officine',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Officine'), findsOneWidget);
      expect(find.text('Rechercher un médicament…'), findsOneWidget);
      expect(find.text('Aucune boîte dans cette officine'), findsOneWidget);
    });
  });
}
