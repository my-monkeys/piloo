// Widget tests pour Aujourd'hui (#115).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/today/presentation/today_screen.dart';

Widget _harness() {
  return const MaterialApp(home: TodayScreen());
}

void main() {
  group('TodayScreen', () {
    testWidgets('rendu : header + day picker + 4 sections + cards mock',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // Header
      expect(find.text("Aujourd'hui"), findsOneWidget);
      // Day picker mock (lundi 20 avril 2026)
      expect(find.text('LUNDI'), findsOneWidget);
      expect(find.text('20 avril'), findsOneWidget);

      // 4 sections
      expect(find.text('Matin'), findsOneWidget);
      expect(find.text('Midi'), findsOneWidget);
      expect(find.text('Soir'), findsOneWidget);
      expect(find.text('Coucher'), findsOneWidget);

      // Compteurs : "Soir" doit être ambre (1 oubliée)
      expect(find.text('1 oubliée'), findsOneWidget);

      // Cards mock — au moins le nom des prises doit apparaître
      expect(find.text('Doliprane 1000 mg'), findsOneWidget);
      expect(find.text('Kardegic 75 mg'), findsOneWidget);
      expect(find.text('Metformine 500 mg'), findsOneWidget);
      expect(find.text('Ramipril 5 mg'), findsOneWidget);
      expect(find.text('Lercanidipine 10 mg'), findsOneWidget);
      expect(find.text('Oubliée'), findsOneWidget);
    });

  });
}
