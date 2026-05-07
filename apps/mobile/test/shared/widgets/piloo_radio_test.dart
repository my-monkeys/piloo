// Tests pour PilooRadio (#55).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/widgets/piloo_radio.dart';

Widget _harness(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('PilooRadio', () {
    testWidgets('non sélectionné : bordure border, dot scale 0', (tester) async {
      await tester.pumpWidget(_harness(PilooRadio<String>(
        value: 'a',
        groupValue: 'b',
        onChanged: (_) {},
      )));
      await tester.pumpAndSettle();

      final c = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final dec = c.decoration! as BoxDecoration;
      expect(dec.border?.top.color, PilooColors.border);

      // Avec scale 0, la zone du dot est virtuellement nulle.
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 0.0);
    });

    testWidgets('sélectionné : bordure primary, dot scale 1', (tester) async {
      await tester.pumpWidget(_harness(PilooRadio<String>(
        value: 'a',
        groupValue: 'a',
        onChanged: (_) {},
      )));
      await tester.pumpAndSettle();

      final c = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final dec = c.decoration! as BoxDecoration;
      expect(dec.border?.top.color, PilooColors.primary);
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1.0);
    });

    testWidgets('tap sur radio non sélectionné : onChanged(value)',
        (tester) async {
      String? captured;
      await tester.pumpWidget(_harness(PilooRadio<String>(
        value: 'edit',
        groupValue: 'view',
        onChanged: (v) => captured = v,
      )));
      await tester.tap(find.byType(PilooRadio<String>));
      await tester.pumpAndSettle();
      expect(captured, 'edit');
    });

    testWidgets('Semantics : checked + inMutuallyExclusiveGroup',
        (tester) async {
      await tester.pumpWidget(_harness(PilooRadio<String>(
        value: 'edit',
        groupValue: 'edit',
        onChanged: (_) {},
        semanticsLabel: 'Éditeur',
      )));
      expect(
        tester.getSemantics(find.byType(PilooRadio<String>)),
        matchesSemantics(
          label: 'Éditeur',
          isButton: true,
          hasTapAction: true,
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
    });
  });
}
