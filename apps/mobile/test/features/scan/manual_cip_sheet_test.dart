// Widget tests pour le bottom sheet de saisie manuelle CIP13 (#85).
//
// Couvre les 4 cas de validation côté UI :
//   - vide                → erreur "13 chiffres"
//   - non 13 chiffres     → erreur format
//   - mauvais préfixe     → erreur "ne ressemble pas à un CIP13 français"
//   - valide              → pop avec ScanResult(cip13)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piloo/features/scan/data/scan_result.dart';
import 'package:piloo/features/scan/presentation/manual_cip_sheet.dart';

Widget _harness({required void Function(BuildContext) onPressed}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => onPressed(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('showManualCipSheet', () {
    testWidgets('CIP vide → message d\'erreur', (tester) async {
      await tester.pumpWidget(_harness(
        onPressed: (ctx) => showManualCipSheet(ctx),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer'));
      await tester.pump();

      expect(
        find.text('Saisis le code à 13 chiffres au dos de la boîte.'),
        findsOneWidget,
      );
    });

    testWidgets('CIP non 13 chiffres → message d\'erreur format', (tester) async {
      await tester.pumpWidget(_harness(
        onPressed: (ctx) => showManualCipSheet(ctx),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('Continuer'));
      await tester.pump();

      expect(find.text('Le CIP13 doit faire 13 chiffres.'), findsOneWidget);
    });

    testWidgets('CIP mauvais préfixe → message "pas un CIP13 français"',
        (tester) async {
      await tester.pumpWidget(_harness(
        onPressed: (ctx) => showManualCipSheet(ctx),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234567890123');
      await tester.tap(find.text('Continuer'));
      await tester.pump();

      expect(
        find.text('Ce code ne ressemble pas à un CIP13 français.'),
        findsOneWidget,
      );
    });

    testWidgets('CIP valide (3400…) → pop avec ScanResult', (tester) async {
      ScanResult? result;
      await tester.pumpWidget(_harness(
        onPressed: (ctx) async {
          result = await showManualCipSheet(ctx);
        },
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '3400934567890');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.cip13, '3400934567890');
      expect(result!.lot, isNull);
      expect(result!.serial, isNull);
      expect(result!.expiry, isNull);
    });

    testWidgets('"Continuer sans CIP" → pop avec null', (tester) async {
      ScanResult? result = const ScanResult(cip13: 'sentinel');
      await tester.pumpWidget(_harness(
        onPressed: (ctx) async {
          result = await showManualCipSheet(ctx);
        },
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer sans CIP'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
