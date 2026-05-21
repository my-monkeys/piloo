// Widget tests pour Fiche médicament (refondue, suite remontée user).
//
// La fiche affiche désormais :
//   - Hero (nom + dosage + forme)
//   - Résumé IA (si présent)
//   - Sections de la notice ANSM scrapée (mock du provider ici)
//   - Lien externe + disclaimer
//   - Infos techniques en accordéon replié (CIS/CIP/laboratoire/etc.)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/inventory/presentation/medicament_info_screen.dart';
import 'package:piloo/shared/bdpm/bdpm_lookup_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_medicament.dart';
import 'package:piloo/shared/bdpm/bdpm_notice_provider.dart';

const _cip = '3400934857188';
const _cis = '60002283';

Widget _harness({
  BdpmMedicament? med,
  BdpmNotice? notice,
}) {
  return ProviderScope(
    overrides: [
      bdpmLookupProvider(_cip).overrideWith((ref) async => med),
      bdpmNoticeProvider(_cis).overrideWith((ref) async =>
          notice ??
          const BdpmNotice(
            cis: _cis,
            sourceUrl: 'http://example.com',
            sections: [],
          )),
    ],
    child: const MaterialApp(home: MedicamentInfoScreen(cip13: _cip)),
  );
}

void main() {
  group('MedicamentInfoScreen', () {
    testWidgets('rendu : hero, résumé IA, lien notice complète, disclaimer, infos techniques (collapsé)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(
        med: const BdpmMedicament(
          cis: _cis,
          cip13: _cip,
          cip7: null,
          denomination: 'DOLIPRANE 1000 mg, comprimé pelliculé',
          forme: 'comprimé pelliculé',
          dosage: '1000 mg',
          voieAdministration: 'orale',
          titulaire: 'SANOFI AVENTIS FRANCE',
          statutAmm: 'Autorisation active',
          tauxRemboursement: 65,
          aiSummary: 'Antalgique et antipyrétique utilisé pour soulager les douleurs.',
        ),
      ));
      await tester.pumpAndSettle();

      // Hero + dosage/forme.
      expect(find.text('Fiche médicament'), findsOneWidget);
      expect(find.text('DOLIPRANE 1000 mg, comprimé pelliculé'), findsOneWidget);
      expect(find.text('1000 mg · comprimé pelliculé'), findsOneWidget);

      // Résumé IA.
      expect(find.text('À QUOI ÇA SERT'), findsOneWidget);
      expect(find.textContaining('Antalgique'), findsOneWidget);

      // Lien externe vers la notice.
      expect(find.textContaining('Voir la notice complète'), findsOneWidget);

      // Disclaimer non-MDR.
      expect(find.textContaining('carnet de suivi personnel'), findsOneWidget);

      // Section infos techniques : header visible, valeurs cachées.
      expect(find.text('Infos techniques'), findsOneWidget);
      expect(find.text('Laboratoire'), findsNothing);

      // Tap pour déplier.
      await tester.tap(find.text('Infos techniques'));
      await tester.pumpAndSettle();
      expect(find.text('Laboratoire'), findsOneWidget);
      expect(find.text('SANOFI AVENTIS FRANCE'), findsOneWidget);
      expect(find.text(_cip), findsOneWidget);
      expect(find.text(_cis), findsOneWidget);
    });

    testWidgets('affiche les sections RCP scrapées (indications + posologie dépliées par défaut)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(
        med: const BdpmMedicament(
          cis: _cis,
          cip13: _cip,
          cip7: null,
          denomination: 'DOLIPRANE',
          forme: null,
          dosage: null,
          voieAdministration: null,
          titulaire: null,
          statutAmm: null,
          tauxRemboursement: null,
        ),
        notice: const BdpmNotice(
          cis: _cis,
          sourceUrl: 'http://example.com',
          sections: [
            NoticeSection(
              number: '4.1',
              title: '4.1. Indications thérapeutiques',
              text: 'Traitement de la douleur.',
            ),
            NoticeSection(
              number: '4.2',
              title: '4.2. Posologie',
              text: 'Adulte : 1 g toutes les 6h.',
            ),
            NoticeSection(
              number: '4.8',
              title: '4.8. Effets indésirables',
              text: 'Rares cas allergiques.',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // 4.1 et 4.2 dépliées par défaut (les plus utiles).
      expect(find.text('Indications'), findsOneWidget);
      expect(find.text('Traitement de la douleur.'), findsOneWidget);
      expect(find.text('Posologie'), findsOneWidget);
      expect(find.text('Adulte : 1 g toutes les 6h.'), findsOneWidget);

      // 4.8 repliée par défaut.
      expect(find.text('Effets indésirables'), findsOneWidget);
      expect(find.text('Rares cas allergiques.'), findsNothing);

      // Tap pour ouvrir 4.8.
      await tester.tap(find.text('Effets indésirables'));
      await tester.pumpAndSettle();
      expect(find.text('Rares cas allergiques.'), findsOneWidget);
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
