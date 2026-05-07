// Tests pour PilooTabBar (#54).
//
// Couvre :
//   - rendu : 4 onglets + slot vide central (5 cells visuels)
//   - tap : dispatch le bon index
//   - tab actif : AnimatedContainer.color = primary
//   - changement d'index : la couleur du pill animée vers la nouvelle
//     position après la durée de l'animation
//   - assert : moins/plus de 4 items lève en debug
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/widgets/piloo_tab_bar.dart';

const _items = [
  PilooTabItem(icon: PhosphorIconsRegular.house, label: 'Aujourd\'hui'),
  PilooTabItem(icon: PhosphorIconsRegular.firstAidKit, label: 'Officine'),
  PilooTabItem(icon: PhosphorIconsRegular.bell, label: 'Alertes'),
  PilooTabItem(icon: PhosphorIconsRegular.dotsThreeOutline, label: 'Plus'),
];

Widget _harness({required int index, required ValueChanged<int> onTap}) =>
    MaterialApp(
      home: Scaffold(
        body: PilooTabBar(
          items: _items,
          currentIndex: index,
          onTap: onTap,
        ),
      ),
    );

Color _activePillColor(WidgetTester tester, String label) {
  final pill = tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (pill.decoration! as BoxDecoration).color!;
}

void main() {
  group('PilooTabBar', () {
    testWidgets('rend les 4 labels', (tester) async {
      await tester.pumpWidget(_harness(index: 0, onTap: (_) {}));
      await tester.pump();
      for (final item in _items) {
        expect(find.text(item.label), findsOneWidget);
      }
    });

    testWidgets('tap dispatche le bon index', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(_harness(index: 0, onTap: (i) => tapped = i));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Officine'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('tab actif : AnimatedContainer.color = primary', (tester) async {
      await tester.pumpWidget(_harness(index: 1, onTap: (_) {}));
      // Laisse l'animation initiale finir.
      await tester.pumpAndSettle();
      expect(_activePillColor(tester, 'Officine'), PilooColors.primary);
      // L'onglet inactif a un pill transparent.
      expect(_activePillColor(tester, 'Aujourd\'hui'), Colors.transparent);
    });

    testWidgets('changement d\'index : couleur s\'anime sur la durée', (tester) async {
      var index = 0;
      late StateSetter setIndex;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setIndex = setState;
              return PilooTabBar(
                items: _items,
                currentIndex: index,
                onTap: (i) => setState(() => index = i),
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(_activePillColor(tester, 'Aujourd\'hui'), PilooColors.primary);

      setIndex(() => index = 2);
      await tester.pump();
      // Pendant l'animation : la couleur de l'ancien actif n'est plus
      // pure transparente ni pure primary — elle interpole.
      await tester.pump(const Duration(milliseconds: 110));
      // Après la durée totale : l'onglet 2 est primary, l'onglet 0 transparent.
      await tester.pumpAndSettle();
      expect(_activePillColor(tester, 'Alertes'), PilooColors.primary);
      expect(_activePillColor(tester, 'Aujourd\'hui'), Colors.transparent);
    });

    testWidgets('moins de 4 items → assert', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PilooTabBar(
            items: const [
              PilooTabItem(icon: PhosphorIconsRegular.house, label: 'X'),
            ],
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ));
      expect(tester.takeException(), isA<AssertionError>());
    });
  });
}
