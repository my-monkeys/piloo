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

@DriftDatabase(tables: [Boites, PrisesPlanifiees, PendingOperations])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(driftDatabase(name: 'piloo_local'));

  /// Pour les tests : permet d'injecter un backend (`NativeDatabase.memory()`)
  /// au lieu de l'ouverture native via `path_provider`.
  LocalDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        // Migrations futures : add `from(N -> N+1)` ici. Tant que
        // `schemaVersion` est inchangé, onUpgrade n'est pas appelé.
        onUpgrade: (m, from, to) async {
          // Espace réservé. Toute évolution doit s'accompagner d'un
          // bump de `schemaVersion` + step explicite.
        },
      );
}
