// Widget tests pour O1 Welcome carousel (#66).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/auth/presentation/welcome_screen.dart';

Widget _harness() {
  return const MaterialApp(home: WelcomeScreen());
}

void main() {
  // Le viewport par défaut de Flutter test (800×600) est trop court pour
  // afficher Hero 380 + texte + bouton sans overflow. On force la taille
  // à un iPhone 13 (390×844) pour que le layout tienne.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.physicalSizeTestValue = const Size(390 * 2, 844 * 2);
    binding.window.devicePixelRatioTestValue = 2.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  });

  group('WelcomeScreen', () {
    testWidgets('rendu : 1ère slide visible + Passer + Suivant', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text("Scanne, c'est tout"), findsOneWidget);
      expect(find.textContaining('DataMatrix au dos'), findsOneWidget);
      expect(find.text('Passer'), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);
    });

    testWidgets('Suivant fait avancer aux slides 2 et 3', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text("Scanne, c'est tout"), findsOneWidget);

      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(find.text('Ne rate plus une prise'), findsOneWidget);

      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(find.text('Avec tes proches'), findsOneWidget);
    });

    testWidgets('sur la dernière slide, label devient "Commencer"', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();

      expect(find.text('Commencer'), findsOneWidget);
      expect(find.text('Suivant'), findsNothing);
    });

    // Le swipe horizontal est géré par PageView (intégrablement testé
    // par Flutter SDK lui-même). Le test "Suivant fait avancer" couvre
    // déjà la sémantique multi-slide.
  });
}
