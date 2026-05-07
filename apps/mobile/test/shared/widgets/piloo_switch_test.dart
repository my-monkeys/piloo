// Tests pour PilooSwitch (#55).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/widgets/piloo_switch.dart';

Widget _harness(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('PilooSwitch', () {
    testWidgets('off : bg border, knob à gauche', (tester) async {
      await tester.pumpWidget(_harness(PilooSwitch(value: false, onChanged: (_) {})));
      await tester.pumpAndSettle();

      final c = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final dec = c.decoration! as BoxDecoration;
      expect(dec.color, PilooColors.border);

      final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(align.alignment, Alignment.centerLeft);
    });

    testWidgets('on : bg primary, knob à droite', (tester) async {
      await tester.pumpWidget(_harness(PilooSwitch(value: true, onChanged: (_) {})));
      await tester.pumpAndSettle();

      final c = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final dec = c.decoration! as BoxDecoration;
      expect(dec.color, PilooColors.primary);

      final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('tap : appelle onChanged inversé', (tester) async {
      bool? captured;
      await tester.pumpWidget(_harness(PilooSwitch(
        value: false,
        onChanged: (v) => captured = v,
      )));
      await tester.tap(find.byType(PilooSwitch));
      await tester.pumpAndSettle();
      expect(captured, true);
    });

    testWidgets('Semantics : toggled + label', (tester) async {
      await tester.pumpWidget(_harness(PilooSwitch(
        value: true,
        onChanged: (_) {},
        semanticsLabel: 'Notifications',
      )));
      expect(
        tester.getSemantics(find.byType(PilooSwitch)),
        matchesSemantics(
          label: 'Notifications',
          hasTapAction: true,
          hasToggledState: true,
          isToggled: true,
        ),
      );
    });
  });
}
