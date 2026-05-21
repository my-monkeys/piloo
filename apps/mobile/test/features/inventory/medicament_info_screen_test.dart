// Widget tests pour Fiche médicament (#99).
//
// Le screen est ConsumerWidget câblé à `bdpmLookupProvider` depuis
// le refactor data-driven. On override avec une donnée fake pour
// vérifier l'affichage, plus un test du chemin "non trouvé" qui
// renvoie l'empty state.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/inventory/presentation/medicament_info_screen.dart';
import 'package:piloo/shared/bdpm/bdpm_lookup_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_medicament.dart';

const _cip = '3400934857188';

Widget _harness({BdpmMedicament? med}) {
  return ProviderScope(
    overrides: [
      bdpmLookupProvider(_cip).overrideWith((ref) async => med),
    ],
    child: const MaterialApp(home: MedicamentInfoScreen(cip13: _cip)),
  );
}

void main() {
  group('MedicamentInfoScreen', () {
    testWidgets('rendu : header + hero + table BDPM + notice', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(
        med: const BdpmMedicament(
          cis: '60002283',
          cip13: _cip,
          cip7: null,
          denomination: 'DOLIPRANE 1000 mg, comprimé pelliculé',
          forme: 'comprimé pelliculé',
          dosage: '1000 mg',
          voieAdministration: 'orale',
          titulaire: 'SANOFI AVENTIS FRANCE',
          statutAmm: 'Autorisation active',
          tauxRemboursement: 65,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Fiche médicament'), findsOneWidget);
      expect(
        find.text('DOLIPRANE 1000 mg, comprimé pelliculé'),
        findsOneWidget,
      );
      expect(find.text('Laboratoire'), findsOneWidget);
      expect(find.text('SANOFI AVENTIS FRANCE'), findsOneWidget);
      expect(find.text('Dosage'), findsOneWidget);
      expect(find.text('1000 mg'), findsOneWidget);
      expect(find.text('Remboursement'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.text(_cip), findsOneWidget);
      // CTA primaire vers le RCP ANSM (remplace l'ancien "Copier le CIP13").
      expect(find.text('Voir la notice officielle'), findsOneWidget);
      expect(find.textContaining('posologie'), findsAtLeast(1));
      // Disclaimer reformulé : pose le positionnement non-MDR explicitement.
      expect(find.textContaining('carnet de suivi personnel'), findsOneWidget);
    });

    testWidgets('empty state quand le CIP est inconnu', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(med: null));
      await tester.pumpAndSettle();

      expect(find.text('Médicament inconnu'), findsOneWidget);
      expect(find.textContaining(_cip), findsAtLeast(1));
    });
  });
}
