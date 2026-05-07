// Tests pour PilooBadge (#53).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/widgets/piloo_badge.dart';

Widget _harness(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

({Color bg, Color fg}) _palette(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(of: find.byType(PilooBadge), matching: find.byType(Container)),
  );
  final bg = (container.decoration! as BoxDecoration).color!;
  final text = tester.widget<Text>(find.byType(Text));
  return (bg: bg, fg: text.style!.color!);
}

void main() {
  group('PilooBadge tones', () {
    testWidgets('neutral (par défaut) → surfaceSubtle / textSecondary',
        (tester) async {
      await tester.pumpWidget(_harness(const PilooBadge(label: 'Actif')));
      final p = _palette(tester);
      expect(p.bg, PilooColors.surfaceSubtle);
      expect(p.fg, PilooColors.textSecondary);
      expect(find.text('Actif'), findsOneWidget);
    });

    testWidgets('success → success / successOn', (tester) async {
      await tester.pumpWidget(_harness(const PilooBadge(
        label: 'OK',
        tone: PilooBadgeTone.success,
      )));
      final p = _palette(tester);
      expect(p.bg, PilooColors.success);
      expect(p.fg, PilooColors.successOn);
    });

    testWidgets('warning → warning / warningOn', (tester) async {
      await tester.pumpWidget(_harness(const PilooBadge(
        label: 'Bientôt périmé',
        tone: PilooBadgeTone.warning,
      )));
      final p = _palette(tester);
      expect(p.bg, PilooColors.warning);
      expect(p.fg, PilooColors.warningOn);
    });

    testWidgets('error → error / errorOn', (tester) async {
      await tester.pumpWidget(_harness(const PilooBadge(
        label: 'Périmé',
        tone: PilooBadgeTone.error,
      )));
      final p = _palette(tester);
      expect(p.bg, PilooColors.error);
      expect(p.fg, PilooColors.errorOn);
    });

    testWidgets('info → info / infoOn', (tester) async {
      await tester.pumpWidget(_harness(const PilooBadge(
        label: 'Info',
        tone: PilooBadgeTone.info,
      )));
      final p = _palette(tester);
      expect(p.bg, PilooColors.info);
      expect(p.fg, PilooColors.infoOn);
    });

    testWidgets('primary → primarySoft / primary', (tester) async {
      await tester.pumpWidget(_harness(const PilooBadge(
        label: 'Pro',
        tone: PilooBadgeTone.primary,
      )));
      final p = _palette(tester);
      expect(p.bg, PilooColors.primarySoft);
      expect(p.fg, PilooColors.primary);
    });
  });
}
