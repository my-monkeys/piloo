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
  tables: [Boites, PrisesPlanifiees, PendingOperations, BdpmNoticesLocal, Rappels],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(driftDatabase(name: 'piloo_local'));

  /// Pour les tests : permet d'injecter un backend (`NativeDatabase.memory()`)
  /// au lieu de l'ouverture native via `path_provider`.
  LocalDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

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
            // v3 : nouvelles tables miroir
            //  - bdpm_notices_local : cache local notices ANSM (cf.
            //    bdpm_notice_provider.dart)
            //  - rappels (#327) : rappels simples sans ordonnance
            //    (pilule, vitamine, etc.)
            await m.createTable(bdpmNoticesLocal);
            await m.createTable(rappels);
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
