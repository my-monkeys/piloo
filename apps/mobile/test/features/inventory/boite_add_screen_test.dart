// Widget tests pour Nouvelle boîte post-scan (#89 + #84).
//
// Le screen est maintenant un ConsumerStatefulWidget qui lit
// scanResultProvider + bdpmDbProvider. On override les deux pour
// couvrir les 3 cas de preview médicament :
//   - scan + DB hit → preview rempli (denomination réelle)
//   - scan + DB miss → preview "non reconnu"
//   - pas de scan → preview "Saisie manuelle"
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piloo/core/storage/secure_storage.dart';
import 'package:piloo/features/auth/data/session_storage.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/inventory/presentation/boite_add_screen.dart';
import 'package:piloo/features/officines/data/active_officine_provider.dart';
import 'package:piloo/features/officines/data/officines_list_provider.dart';
import 'package:piloo/features/scan/data/scan_result.dart';
import 'package:piloo/shared/bdpm/bdpm_db.dart';
import 'package:piloo/shared/bdpm/bdpm_lookup_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_provider.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;
import 'package:sqlite3/sqlite3.dart';

class _NoActiveOfficineNotifier extends ActiveOfficineNotifier {
  @override
  Future<api.Officine?> build() async => null;
}

BdpmDb _fixtureBdpm() {
  final db = sqlite3.openInMemory();
  db.execute('''
    CREATE TABLE bdpm_metadata (key TEXT PRIMARY KEY, value TEXT) WITHOUT ROWID;
    CREATE TABLE medicaments (
      cis TEXT PRIMARY KEY,
      cip13 TEXT, cip7 TEXT,
      denomination TEXT NOT NULL,
      forme TEXT, dosage TEXT,
      voie_administration TEXT,
      titulaire TEXT,
      statut_amm TEXT,
      taux_remboursement INTEGER,
      version_bdpm TEXT NOT NULL
    ) WITHOUT ROWID;
    CREATE INDEX idx_cip13 ON medicaments(cip13) WHERE cip13 IS NOT NULL;
  ''');
  db.execute("INSERT INTO bdpm_metadata VALUES ('version', '2026-05-01')");
  db.execute('''
    INSERT INTO medicaments VALUES (
      '60002283', '3400934567890', NULL,
      'DOLIPRANE 1000 mg, comprimé pelliculé',
      'comprimé pelliculé', '1000 mg', 'orale',
      'SANOFI AVENTIS FRANCE', 'Autorisation active',
      65, '2026-05-01'
    )
  ''');
  return BdpmDb.forTesting(db);
}

Widget _harness({
  ScanResult? initialScan,
  BdpmDb? bdpm,
}) {
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        SessionStorage(InMemorySecureStorage()),
      ),
      activeOfficineProvider.overrideWith(_NoActiveOfficineNotifier.new),
      officinesListProvider.overrideWith((_) async => const <api.Officine>[]),
      bdpmDbProvider.overrideWith((ref) async => bdpm),
      // Le screen utilise désormais bdpmLookupProvider (local + fallback
      // API). En test on court-circuite via le DB local fourni — pas de
      // fallback API. Renvoie null si pas de match local.
      bdpmLookupProvider.overrideWith((ref, cip13) async {
        return bdpm?.findByCip13(cip13);
      }),
      if (initialScan != null)
        scanResultProvider.overrideWith(
          (ref) => ScanResultController()..set(initialScan),
        ),
    ],
    child: const MaterialApp(home: BoiteAddScreen()),
  );
}

void main() {
  group('BoiteAddScreen', () {
    testWidgets('rendu sans scan : preview "Saisie manuelle" + form complet',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle boîte'), findsOneWidget);
      expect(find.text('Saisie manuelle'), findsOneWidget);
      expect(find.text('Sans CIP scanné'), findsOneWidget);

      // Le form lui-même est inchangé.
      expect(find.text('PÉREMPTION'), findsOneWidget);
      expect(find.text('N° DE LOT'), findsOneWidget);
      expect(find.text('OFFICINE CIBLE'), findsOneWidget);
      expect(find.text('NIVEAU INITIAL'), findsOneWidget);
      expect(find.text('Plein'), findsOneWidget);
      expect(find.text('3/4'), findsOneWidget);
      expect(find.text('Moitié'), findsOneWidget);
      expect(find.text('1/4'), findsOneWidget);
      expect(find.text('~Vide'), findsOneWidget);
      expect(find.text('NOTES (OPTIONNEL)'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);
    });

    testWidgets('scan + DB hit : preview rempli avec données BDPM réelles',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scan = ScanResult(
        cip13: '3400934567890',
        lot: 'LOT42AB7',
        expiry: DateTime(2028, 3, 1),
      );
      await tester.pumpWidget(
        _harness(initialScan: scan, bdpm: _fixtureBdpm()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('DOLIPRANE 1000 mg, comprimé pelliculé'),
        findsOneWidget,
      );
      expect(find.text('1000 mg · SANOFI AVENTIS FRANCE'), findsOneWidget);
      expect(find.text('comprimé pelliculé · Remboursé 65%'), findsOneWidget);

      // Lot et péremption pré-remplis depuis le scan.
      expect(find.text('LOT42AB7'), findsOneWidget);
      expect(find.text('03 / 2028'), findsOneWidget);
    });

    testWidgets('scan + CIP inconnu de BDPM : preview "non reconnu"',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scan = ScanResult(cip13: '9999999999999');
      await tester.pumpWidget(
        _harness(initialScan: scan, bdpm: _fixtureBdpm()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Médicament non reconnu'), findsOneWidget);
      expect(find.text('CIP 9999999999999'), findsOneWidget);
    });

    testWidgets('scan + DB indisponible (1er lancement avant download) : non reconnu',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scan = ScanResult(cip13: '3400934567890');
      // bdpm: null → DB non encore téléchargée
      await tester.pumpWidget(_harness(initialScan: scan, bdpm: null));
      await tester.pumpAndSettle();

      expect(find.text('Médicament non reconnu'), findsOneWidget);
    });

    testWidgets('tap sur un chip change la sélection sans crasher',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Moitié'));
      await tester.pumpAndSettle();
      expect(find.text('Plein'), findsOneWidget);
      expect(find.text('Moitié'), findsOneWidget);
    });
  });
}
