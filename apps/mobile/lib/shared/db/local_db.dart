// Base SQLite locale via Drift (#47).
//
// Schéma v1 :
//   - boites
//   - prises_planifiees
//   - pending_operations
//
// La BDPM (read-only, ~60 Mo) vivra dans une base attachée séparée
// téléchargée au 1er lancement (cf. ticket #78) — pas dans cette base.
//
// Tests : la factory `LocalDatabase.test()` accepte un
// `NativeDatabase.memory()` pour exécuter en mémoire sans pre-installer
// les libs sqlite Flutter natives.
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'local_db.g.dart';

@DriftDatabase(
  tables: [Boites, PrisesPlanifiees, PendingOperations, BdpmNoticesLocal],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(driftDatabase(name: 'piloo_local'));

  /// Pour les tests : permet d'injecter un backend (`NativeDatabase.memory()`)
  /// au lieu de l'ouverture native via `path_provider`.
  LocalDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createPendingOpsIndex(m);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2 (#90) : index sur pending_operations.statut pour le
            // worker de sync (#91) — il interroge en boucle les ops
            // `pending`, un scan full-table à chaque tick coûte cher.
            await _createPendingOpsIndex(m);
          }
          if (from < 3) {
            // v3 : nouvelle table miroir bdpm_notices_local (cache
            // local notices ANSM, cf. bdpm_notice_provider.dart).
            await m.createTable(bdpmNoticesLocal);
          }
          if (from < 4) {
            // v4 (2026-05-22) : suppression de la table `rappels`.
            // L'écran dédié a été remplacé par "Plus → Nouveau rappel"
            // qui pousse vers OrdonnanceCreateScreen. DROP IF EXISTS
            // car les users qui n'ont jamais atteint v3 n'ont pas la
            // table — pas d'erreur.
            await m.database
                .customStatement('DROP TABLE IF EXISTS rappels');
          }
        },
      );

  Future<void> _createPendingOpsIndex(Migrator m) async {
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pending_ops_statut '
      'ON pending_operations(statut)',
    );
  }
}
