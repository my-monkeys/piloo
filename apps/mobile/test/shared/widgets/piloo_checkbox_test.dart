// Tests pour PilooCheckbox (#55).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/widgets/piloo_checkbox.dart';

Widget _harness(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('PilooCheckbox', () {
    testWidgets('décoché : surface + border, pas d\'icône', (tester) async {
      await tester.pumpWidget(_harness(PilooCheckbox(value: false, onChanged: (_) {})));
      final c = tester.widget<Container>(
        find.descendant(of: find.byType(PilooCheckbox), matching: find.byType(Container)),
      );
      final dec = c.decoration! as BoxDecoration;
      expect(dec.color, PilooColors.surface);
      expect(dec.border, isNotNull);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('coché : primary + check icon visible', (tester) async {
      await tester.pumpWidget(_harness(PilooCheckbox(value: true, onChanged: (_) {})));
      final c = tester.widget<Container>(
        find.descendant(of: find.byType(PilooCheckbox), matching: find.byType(Container)),
      );
      final dec = c.decoration! as BoxDecoration;
      expect(dec.color, PilooColors.primary);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('tap : appelle onChanged avec valeur inversée', (tester) async {
      bool? captured;
      await tester.pumpWidget(_harness(PilooCheckbox(
        value: false,
        onChanged: (v) => captured = v,
      )));
      await tester.tap(find.byType(PilooCheckbox));
      await tester.pumpAndSettle();
      expect(captured, true);
    });

    testWidgets('Semantics : checked reflète value', (tester) async {
      await tester.pumpWidget(_harness(PilooCheckbox(
        value: true,
        onChanged: (_) {},
        semanticsLabel: 'CGU',
      )));
      expect(
        tester.getSemantics(find.byType(PilooCheckbox)),
        matchesSemantics(
          label: 'CGU',
          isButton: true,
          hasTapAction: true,
          hasCheckedState: true,
          isChecked: true,
        ),
      );
    });
  });
}
