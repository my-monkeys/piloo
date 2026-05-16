// Tests pendingCountProvider (#95).
//
// On instancie une `LocalDatabase` mémoire et on watch le compteur ;
// chaque insert/update/delete sur `pending_operations` doit propager
// une nouvelle valeur au stream.
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/shared/db/local_db.dart';
import 'package:piloo/shared/sync/pending_count_provider.dart';

LocalDatabase _mem() => LocalDatabase.forTesting(NativeDatabase.memory());

PendingOperationsCompanion _op(String id, {String statut = 'pending'}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return PendingOperationsCompanion.insert(
    id: id,
    type: 'mark_taken',
    entityType: 'prise_planifiee',
    entityId: 'prise-$id',
    payload: '{}',
    timestampLocal: DateTime.now().millisecondsSinceEpoch,
    createdAt: now,
    updatedAt: now,
    statut: drift.Value(statut),
  );
}

void main() {
  group('watchPendingCount', () {
    late LocalDatabase db;

    setUp(() {
      db = _mem();
    });

    tearDown(() async {
      await db.close();
    });

    test('émet 0 sur base vide', () async {
      final stream = watchPendingCount(db);
      expect(await stream.first, 0);
    });

    test('compte uniquement les ops en statut pending', () async {
      await db.into(db.pendingOperations).insert(_op('a'));
      await db.into(db.pendingOperations).insert(_op('b'));
      await db.into(db.pendingOperations).insert(_op('c', statut: 'acked'));

      final stream = watchPendingCount(db);
      expect(await stream.first, 2);
    });

    test('réagit aux inserts puis retourne à 0 après deletes/acked', () async {
      // 1. Insertion : passe de 0 à 2.
      await db.into(db.pendingOperations).insert(_op('a'));
      await db.into(db.pendingOperations).insert(_op('b'));
      expect(await watchPendingCount(db).first, 2);

      // 2. ack + delete : retour à 0.
      await (db.update(db.pendingOperations)..where((o) => o.id.equals('a')))
          .write(const PendingOperationsCompanion(
        statut: drift.Value('acked'),
      ));
      await (db.delete(db.pendingOperations)..where((o) => o.id.equals('b')))
          .go();
      expect(await watchPendingCount(db).first, 0);
    });
  });
}
