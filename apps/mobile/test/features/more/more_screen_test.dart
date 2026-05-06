// Widget tests pour Plus / Paramètres (#151).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/more/presentation/more_screen.dart';

Widget _harness() {
  return const MaterialApp(home: MoreScreen());
}

void main() {
  group('MoreScreen', () {
    testWidgets('rendu : header + profil + 3 sections + logout + version',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Plus'), findsOneWidget);

      // Profil
      expect(find.text('MD'), findsOneWidget);
      expect(find.text('Maxime Durand'), findsOneWidget);
      expect(find.text('maxime@exemple.fr'), findsOneWidget);

      // 3 sections
      expect(find.text('MON APP'), findsOneWidget);
      expect(find.text('PRÉFÉRENCES'), findsOneWidget);
      expect(find.text('AIDE & LÉGAL'), findsOneWidget);

      // Quelques rows
      expect(find.text('Mes officines'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Push + Email'), findsOneWidget);
      expect(find.text('Horaires par défaut'), findsOneWidget);
      expect(find.text('Langue'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
      expect(find.text("Ce n'est pas un dispositif médical"), findsOneWidget);

      // Footer
      expect(find.text('Se déconnecter'), findsOneWidget);
      expect(find.text('Piloo v0.1.0 · BDPM 2026-04'), findsOneWidget);
    });
  });
}
