// Widget tests pour O3 Permissions (#68).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/auth/presentation/permissions_screen.dart';

Widget _harness() {
  return const MaterialApp(home: PermissionsScreen());
}

void main() {
  group('PermissionsScreen', () {
    testWidgets('rendu : titre + 2 cartes (caméra/notifs) + '
        'help + 2 boutons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Quelques autorisations'), findsOneWidget);
      expect(
        find.textContaining('Pour que Piloo fonctionne au mieux'),
        findsOneWidget,
      );
      expect(find.text('Caméra'), findsOneWidget);
      expect(find.text('Pour scanner le DataMatrix des boîtes'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(
        find.text('Rappels de prise et alertes péremption'),
        findsOneWidget,
      );
      // Pas de carte Contacts : permission retirée (#398) — l'app ne lit
      // aucun carnet d'adresses.
      expect(find.text('Contacts (optionnel)'), findsNothing);
      expect(find.text('Requis'), findsOneWidget);
      expect(
        find.textContaining('On ne partage ces accès'),
        findsOneWidget,
      );
      expect(find.text('Terminer'), findsOneWidget);
      expect(find.text("Ignorer pour l'instant"), findsOneWidget);
    });
  });
}
