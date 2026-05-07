// Tests pour PilooCard (#53).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/widgets/piloo_card.dart';

Widget _harness(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('PilooCard', () {
    testWidgets('non tappable : Container avec surface + border', (tester) async {
      await tester.pumpWidget(_harness(const PilooCard(child: Text('hello'))));

      // Pas de Material/InkWell si onTap est null.
      expect(
        find.descendant(of: find.byType(PilooCard), matching: find.byType(InkWell)),
        findsNothing,
      );
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(PilooCard), matching: find.byType(Container)),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, PilooColors.surface);
      expect(decoration.border, isNotNull);
    });

    testWidgets('tappable : InkWell présent et onTap appelé', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(PilooCard(
        onTap: () => taps++,
        child: const Text('hello'),
      )));

      expect(
        find.descendant(of: find.byType(PilooCard), matching: find.byType(InkWell)),
        findsOneWidget,
      );
      await tester.tap(find.byType(PilooCard));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('color/borderColor overrides appliqués', (tester) async {
      await tester.pumpWidget(_harness(const PilooCard(
        color: Color(0xFF123456),
        borderColor: Color(0xFFABCDEF),
        child: SizedBox.shrink(),
      )));
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(PilooCard), matching: find.byType(Container)),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF123456));
      expect(decoration.border?.top.color, const Color(0xFFABCDEF));
    });
  });
}
