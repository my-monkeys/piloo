// Tests pour PilooScanFab (#54).
//
// Couvre :
//   - tap : appelle onTap
//   - press : AnimatedScale.scale = 0.95 pendant le press, 1.0 après
//   - rendu : icône scan visible
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/shared/widgets/piloo_scan_fab.dart';

Widget _harness({required VoidCallback onTap}) => MaterialApp(
      home: Scaffold(
        body: Center(child: PilooScanFab(onTap: onTap)),
      ),
    );

double _currentScale(WidgetTester tester) {
  final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
  return scale.scale;
}

void main() {
  group('PilooScanFab', () {
    testWidgets('rendu : icône scan visible', (tester) async {
      await tester.pumpWidget(_harness(onTap: () {}));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, PhosphorIconsRegular.scan);
    });

    testWidgets('tap : appelle onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(onTap: () => taps++));
      await tester.pumpAndSettle();
      // GestureDetector cible directement la zone réellement hittable —
      // le FAB est `Transform.translate`-é hors de son centre logique.
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('press : scale 0.95 pendant l\'appui, 1.0 après release',
        (tester) async {
      await tester.pumpWidget(_harness(onTap: () {}));
      await tester.pumpAndSettle();
      expect(_currentScale(tester), 1.0);

      final gesture = await tester.press(find.byType(GestureDetector));
      await tester.pump();
      expect(_currentScale(tester), 0.95);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_currentScale(tester), 1.0);
    });
  });
}
