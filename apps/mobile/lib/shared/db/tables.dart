// Tables Drift miroirs côté mobile (#47). Reflètent les tables Postgres
// correspondantes (cf. packages/db-schema/src/schema/) en gardant la
// compatibilité de type pour la sync.
//
// Décisions :
// - Pas de FOREIGN KEYs Drift (les batchs de sync peuvent arriver dans
//   un ordre où un enfant précède son parent ; les violations se gèrent
//   au niveau applicatif).
// - IDs en `text` plutôt que `uuid` natif : SQLite n'a pas de type
//   uuid dédié, on garde la même string-représentation que côté
//   Postgres (génération via `crypto.randomUUID()` côté serveur ou
//   `Uuid().v4()` côté Dart).
// - `deleted_at` partout (soft delete, identique au schéma Postgres).
// - Timestamps en ms epoch UTC (`Int64`) — le converter vers `DateTime`
//   est géré par le type Drift `IntColumn().mapTo<DateTime>()` quand
//   on en aura besoin. Pour le POC, on stocke en text ISO 8601 (lisible
//   en debug, simple à comparer).
import 'package:drift/drift.dart';

@DataClassName('BoiteRow')
class Boites extends Table {
  TextColumn get id => text()();
  TextColumn get officineId => text()();
  TextColumn get cip13 => text()();
  TextColumn get lot => text().nullable()();
  TextColumn get numeroSerie => text().nullable()();
  TextColumn get peremption => text()(); // ISO date YYYY-MM-DD
  IntColumn get unitesInitiales => integer().nullable()();
  IntColumn get unitesRestantes => integer().nullable()();
  TextColumn get statut =>
      text().withDefault(const Constant('active'))(); // active|vide|perimee
  TextColumn get notes => text().nullable()();
  TextColumn get ajouteePar => text()();
  TextColumn get createdAt => text()(); // ISO 8601 UTC
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PrisePlanifieeRow')
class PrisesPlanifiees extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId => text()();
  TextColumn get officineId => text()();
  TextColumn get datetimePrevue => text()(); // ISO 8601 UTC
  TextColumn get datetimeValidation => text().nullable()();
  TextColumn get statut =>
      text().withDefault(const Constant('prevue'))(); // prevue|prise|sautee|oubliee
  TextColumn get valideePar => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PendingOperationRow')
class PendingOperations extends Table {
  // Journal append-only des opérations locales en attente de sync
  // (cf. /CLAUDE.md racine §"Offline-first" et docs/architecture.md
  // §"Synchronisation").
  TextColumn get id => text()(); // uuid v4 client-side
  TextColumn get type => text()(); // create_boite | update_prise | ...
  TextColumn get entityType => text()(); // boite | prise_planifiee | ...
  TextColumn get entityId => text()();
  TextColumn get payload => text()(); // JSON encoded
  IntColumn get timestampLocal => integer()(); // ms epoch local
  TextColumn get statut =>
      text().withDefault(const Constant('pending'))(); // pending|sent|acked|rejected
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
