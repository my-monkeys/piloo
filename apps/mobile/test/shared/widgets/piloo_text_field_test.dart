// Tests pour PilooTextField (#55).
//
// Couvre :
//   - rendu : label uppercase + hint
//   - focus : bordure devient primary quand focus
//   - erreur : bordure errorOn + message visible + Semantics value annoncé
//   - obscure password : eye toggle
//   - Semantics(textField: true)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/widgets/piloo_text_field.dart';

Widget _harness(Widget child) =>
    MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: child)));

Color _borderColor(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(PilooTextField),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration! as BoxDecoration).border!.top.color;
}

void main() {
  group('PilooTextField', () {
    testWidgets('rendu : label uppercase + hint', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(_harness(PilooTextField(
        label: 'Email',
        hint: 'vous@exemple.fr',
        controller: ctrl,
      )));
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('vous@exemple.fr'), findsOneWidget);
    });

    testWidgets('focus : bordure devient primary', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(_harness(PilooTextField(
        label: 'Email',
        controller: ctrl,
      )));
      expect(_borderColor(tester), PilooColors.border);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(_borderColor(tester), PilooColors.primary);
    });

    testWidgets('errorText : bordure errorOn + message + Semantics value',
        (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(_harness(PilooTextField(
        label: 'Email',
        errorText: 'Email invalide.',
        controller: ctrl,
      )));
      await tester.pumpAndSettle();

      expect(_borderColor(tester), PilooColors.errorOn);
      expect(find.text('Email invalide.'), findsOneWidget);

      // testWidgets active déjà la semantics ; pas besoin d'ensureSemantics().
      final semantics = tester.getSemantics(find.byType(PilooTextField));
      expect(semantics.value, contains('erreur'));
    });

    testWidgets('obscure : eye toggle bascule l\'affichage du password',
        (tester) async {
      final ctrl = TextEditingController(text: 'secret');
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(_harness(PilooTextField(
        label: 'Mot de passe',
        controller: ctrl,
        obscure: true,
      )));

      var tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.obscureText, true);

      // L'eye toggle est l'unique GestureDetector.
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pumpAndSettle();

      tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.obscureText, false);
    });
  });
}
