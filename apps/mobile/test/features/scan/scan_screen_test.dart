// Widget tests pour Scan viewfinder (#82).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/scan/presentation/scan_screen.dart';

Widget _harness() {
  return const MaterialApp(home: ScanScreen());
}

void main() {
  group('ScanScreen', () {
    testWidgets('rendu : top bar + eyebrow + viewfinder + helper + saisie',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      // Pas de pumpAndSettle : la scan line boucle infiniment.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SCANNER UNE BOÎTE'), findsOneWidget);
      expect(
        find.text('Cadre le DataMatrix au dos de la boîte'),
        findsOneWidget,
      );
      expect(find.text('Saisie manuelle'), findsOneWidget);
    });
  });
}
