// Tests pour PilooButton (#52).
//
// Couvre :
//   - 4 variants : primary / outline / apple / google rendent des
//     couleurs / borders / icônes attendues
//   - état loading : spinner visible, label caché, onTap ignoré
//   - état disabled (onPressed null) : opacity 0.5, onTap ignoré
//   - 3 tailles : padding et fontSize cohérents avec PilooButtonSize
//
// Pas de golden file ici : vérifier que les pixels matchent une
// baseline est fragile en CI multi-plateforme. On préfère asserter la
// structure de widgets (Icon présent, padding correct, opacity
// attendue) — ça casse pour les bonnes raisons et plus tôt.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';

Widget _harness(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('PilooButton variants', () {
    testWidgets('primary : background = primary', (tester) async {
      await tester.pumpWidget(_harness(PilooButton(
        label: 'Continuer',
        onPressed: () {},
      )));
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(PilooButton), matching: find.byType(Material)),
      );
      expect(material.color, PilooColors.primary);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('outline : transparent + border', (tester) async {
      await tester.pumpWidget(_harness(PilooButton(
        label: 'Annuler',
        variant: PilooButtonVariant.outline,
        onPressed: () {},
      )));
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(PilooButton), matching: find.byType(Material)),
      );
      expect(material.color, Colors.transparent);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, PilooColors.border);
    });

    testWidgets('apple : icône appleLogo + bg quasi-noir', (tester) async {
      await tester.pumpWidget(_harness(PilooButton(
        label: 'Continuer avec Apple',
        variant: PilooButtonVariant.apple,
        onPressed: () {},
      )));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, PhosphorIconsFill.appleLogo);
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(PilooButton), matching: find.byType(Material)),
      );
      expect(material.color, const Color(0xFF111111));
    });

    testWidgets('google : icône googleLogo + bg surface + border', (tester) async {
      await tester.pumpWidget(_harness(PilooButton(
        label: 'Continuer avec Google',
        variant: PilooButtonVariant.google,
        onPressed: () {},
      )));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, PhosphorIconsRegular.googleLogo);
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(PilooButton), matching: find.byType(Material)),
      );
      expect(material.color, PilooColors.surface);
    });
  });

  group('PilooButton states', () {
    testWidgets('loading : spinner visible, label caché, onTap ignoré',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(PilooButton(
        label: 'Envoi',
        isLoading: true,
        onPressed: () => taps++,
      )));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Envoi'), findsNothing);

      await tester.tap(find.byType(PilooButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('disabled (onPressed null) : opacity 0.5, onTap ignoré',
        (tester) async {
      await tester.pumpWidget(_harness(const PilooButton(label: 'X')));

      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(PilooButton), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 0.5);

      // Tap should not throw and not crash.
      await tester.tap(find.byType(PilooButton));
      await tester.pump();
    });

    testWidgets('actif : opacity 1.0 et tap appelle onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(PilooButton(
        label: 'X',
        onPressed: () => taps++,
      )));

      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(PilooButton), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 1.0);

      await tester.tap(find.byType(PilooButton));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('PilooButton sizes', () {
    testWidgets('small : padding 14/10 + font 13', (tester) async {
      await tester.pumpWidget(_harness(PilooButton(
        label: 'X',
        size: PilooButtonSize.small,
        onPressed: () {},
      )));
      final padding = tester.widget<Padding>(
        find.descendant(of: find.byType(PilooButton), matching: find.byType(Padding)),
      );
      expect(padding.padding, const EdgeInsets.symmetric(horizontal: 14, vertical: 10));
      final text = tester.widget<Text>(find.text('X'));
      expect(text.style?.fontSize, 13);
    });

    testWidgets('medium (default) : padding 20/14 + font 15', (tester) async {
      await tester.pumpWidget(_harness(PilooButton(
        label: 'X',
        onPressed: () {},
      )));
      final padding = tester.widget<Padding>(
        find.descendant(of: find.byType(PilooButton), matching: find.byType(Padding)),
      );
      expect(padding.padding, const EdgeInsets.symmetric(horizontal: 20, vertical: 14));
      final text = tester.widget<Text>(find.text('X'));
      expect(text.style?.fontSize, 15);
    });

    testWidgets('large : padding 24/18 + font 17', (tester) async {
      await tester.pumpWidget(_harness(PilooButton(
        label: 'X',
        size: PilooButtonSize.large,
        onPressed: () {},
      )));
      final padding = tester.widget<Padding>(
        find.descendant(of: find.byType(PilooButton), matching: find.byType(Padding)),
      );
      expect(padding.padding, const EdgeInsets.symmetric(horizontal: 24, vertical: 18));
      final text = tester.widget<Text>(find.text('X'));
      expect(text.style?.fontSize, 17);
    });
  });
}
