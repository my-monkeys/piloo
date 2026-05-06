// Tests Drift LocalDatabase (#47).
// Couverture : la migration v1 crée bien les 3 tables, on peut insérer
// puis re-lire un enregistrement dans chacune, le soft delete est
// observable, l'index implicite (PK) rejette les doublons d'id.
// Conflit de nom : `isNull` existe à la fois dans drift (matcher SQL) et
// dans matcher (matcher de test). On `hide` côté drift puisque dans le
// fichier on utilise les deux : drift's via la callback `(b) => ...`
// (qui prend une `$BoitesTable`, accès direct à la column expression),
// et matcher's via `expect(..., isNull)`.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/shared/db/local_db.dart';

LocalDatabase makeDb() {
  final db = LocalDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

void main() {
  group('LocalDatabase v1', () {
    test('schemaVersion vaut 1', () {
      final db = makeDb();
      expect(db.schemaVersion, 1);
    });

    test('migration v1 crée les 3 tables attendues', () async {
      final db = makeDb();
      // Force open + migration
      await db.customSelect("SELECT 1").get();

      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name NOT LIKE 'sqlite_%' "
            "ORDER BY name",
          )
          .get();

      final names = tables.map((r) => r.read<String>('name')).toList();
      expect(names, containsAll(['boites', 'prises_planifiees', 'pending_operations']));
    });

    test('insert + select sur boites', () async {
      final db = makeDb();
      await db.into(db.boites).insert(
            BoitesCompanion.insert(
              id: 'boite-1',
              officineId: 'officine-1',
              cip13: '3400930000019',
              peremption: '2027-01-01',
              ajouteePar: 'user-1',
              createdAt: '2026-05-06T12:00:00Z',
              updatedAt: '2026-05-06T12:00:00Z',
              lot: const Value('LOT-A'),
              numeroSerie: const Value('SN-001'),
              unitesInitiales: const Value(16),
              unitesRestantes: const Value(12),
            ),
          );

      final rows = await db.select(db.boites).get();
      expect(rows, hasLength(1));
      expect(rows.first.id, 'boite-1');
      expect(rows.first.statut, 'active'); // default
      expect(rows.first.deletedAt, isNull);
    });

    test('soft delete filtrable via where deletedAt is null', () async {
      final db = makeDb();
      final base = BoitesCompanion.insert(
        id: 'boite-1',
        officineId: 'officine-1',
        cip13: '3400930000019',
        peremption: '2027-01-01',
        ajouteePar: 'user-1',
        createdAt: '2026-05-06T12:00:00Z',
        updatedAt: '2026-05-06T12:00:00Z',
      );
      await db.into(db.boites).insert(base);
      await db.into(db.boites).insert(
            base.copyWith(
              id: const Value('boite-2'),
              deletedAt: const Value('2026-05-06T13:00:00Z'),
            ),
          );

      final actives = await (db.select(db.boites)
            ..where((b) => b.deletedAt.isNull()))
          .get();
      expect(actives, hasLength(1));
      expect(actives.first.id, 'boite-1');
    });

    test('insert dans prises_planifiees + pending_operations', () async {
      final db = makeDb();
      await db.into(db.prisesPlanifiees).insert(
            PrisesPlanifieesCompanion.insert(
              id: 'prise-1',
              prescriptionId: 'rx-1',
              officineId: 'officine-1',
              datetimePrevue: '2026-05-07T08:00:00Z',
              createdAt: '2026-05-06T12:00:00Z',
              updatedAt: '2026-05-06T12:00:00Z',
            ),
          );
      await db.into(db.pendingOperations).insert(
            PendingOperationsCompanion.insert(
              id: 'op-1',
              type: 'create_boite',
              entityType: 'boite',
              entityId: 'boite-1',
              payload: '{"cip13":"3400930000019"}',
              timestampLocal: 1746528000000,
              createdAt: '2026-05-06T12:00:00Z',
              updatedAt: '2026-05-06T12:00:00Z',
            ),
          );

      final prises = await db.select(db.prisesPlanifiees).get();
      expect(prises, hasLength(1));
      expect(prises.first.statut, 'prevue');

      final ops = await db.select(db.pendingOperations).get();
      expect(ops, hasLength(1));
      expect(ops.first.statut, 'pending');
      expect(ops.first.retryCount, 0);
    });

    test('PK rejette un id dupliqué', () async {
      final db = makeDb();
      await db.into(db.boites).insert(
            BoitesCompanion.insert(
              id: 'boite-1',
              officineId: 'officine-1',
              cip13: '3400930000019',
              peremption: '2027-01-01',
              ajouteePar: 'user-1',
              createdAt: '2026-05-06T12:00:00Z',
              updatedAt: '2026-05-06T12:00:00Z',
            ),
          );

      await expectLater(
        db.into(db.boites).insert(
              BoitesCompanion.insert(
                id: 'boite-1',
                officineId: 'officine-2',
                cip13: '3400930000019',
                peremption: '2027-01-01',
                ajouteePar: 'user-1',
                createdAt: '2026-05-06T12:00:00Z',
                updatedAt: '2026-05-06T12:00:00Z',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
