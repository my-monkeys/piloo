// Widget tests pour Officine inventaire (#87).
//
// Le screen est ConsumerStatefulWidget depuis PR feat/mobile-wire-prod-api.
// On override `sessionStorageProvider` avec un SecureStorage in-memory
// (sinon il throw UnimplementedError, qui plante la chaîne
// activeOfficineProvider). L'API n'est pas mockée — l'appel /v1/officines
// échoue silencieusement (timeout dans le runtime de test), l'écran
// retombe sur la liste mock de fallback. C'est exactement ce qu'on teste.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/storage/secure_storage.dart';
import 'package:piloo/features/auth/data/session_storage.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/officine/presentation/officine_screen.dart';

Widget _harness() {
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        SessionStorage(InMemorySecureStorage()),
      ),
    ],
    child: const MaterialApp(home: OfficineScreen()),
  );
}

void main() {
  group('OfficineScreen', () {
    testWidgets('rendu : header + switcher + recherche + filtres + cards',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Officine'), findsOneWidget);
      expect(find.text('Maison'), findsOneWidget);
      // Le sous-titre affiche maintenant la vraie length de la liste
      // (mock fallback = 6 quand l'API ne répond pas en test).
      expect(find.text('6 boîtes'), findsOneWidget);
      expect(find.text('Rechercher un médicament…'), findsOneWidget);

      // Filtres avec compteurs (skipOffstage:false car la rangée est
      // une ListView horizontale, certains chips peuvent être hors
      // viewport).
      expect(find.text('Tout · 6'), findsOneWidget);
      expect(find.text('Actif'), findsOneWidget);
      expect(find.text('Périmé · 1', skipOffstage: false), findsOneWidget);
      expect(find.text('Stock bas · 1', skipOffstage: false), findsOneWidget);

      // Cards mock
      expect(find.text('Doliprane 1000 mg'), findsOneWidget);
      expect(find.text('Kardegic 75 mg'), findsOneWidget);
      expect(find.text('Metformine 500 mg'), findsOneWidget);
      expect(find.text('Amoxicilline 500 mg'), findsOneWidget);
      expect(find.text('Humex rhume'), findsOneWidget);
      expect(
        find.text('Périmée depuis 14 jours · à jeter'),
        findsOneWidget,
      );
    });

    testWidgets('filtre Périmé ne garde que la card périmée',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // ListView horizontale : on s'assure que le chip est visible
      // avant de taper.
      await tester.scrollUntilVisible(
        find.text('Périmé · 1'),
        50,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Périmé · 1'));
      await tester.pumpAndSettle();

      expect(find.text('Amoxicilline 500 mg'), findsOneWidget);
      expect(find.text('Doliprane 1000 mg'), findsNothing);
      expect(find.text('Kardegic 75 mg'), findsNothing);
    });
  });
}
