// Tests unitaires enqueueOperation (#56).
//
// Sanity check : l'op se retrouve bien en base avec statut 'pending',
// payload JSON sérialisé, et un id UUID unique.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/shared/db/local_db.dart';
import 'package:piloo/shared/sync/enqueue.dart';

void main() {
  late LocalDatabase db;

  setUp(() {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('enqueueOperation insère une ligne pending', () async {
    final id = await enqueueOperation(
      db,
      const EnqueueOp(
        type: 'update_boite',
        entityType: 'boite',
        entityId: 'b6f1c0ee-0d4a-4ac5-8901-6f4dafe6b6c2',
        payload: {'statut': 'vide', 'unites_restantes': 0},
      ),
    );

    final rows = await db.select(db.pendingOperations).get();
    expect(rows, hasLength(1));
    final row = rows.first;
    expect(row.id, equals(id));
    expect(row.type, equals('update_boite'));
    expect(row.entityType, equals('boite'));
    expect(row.entityId, equals('b6f1c0ee-0d4a-4ac5-8901-6f4dafe6b6c2'));
    expect(row.statut, equals('pending'));
    expect(row.retryCount, equals(0));
    expect(jsonDecode(row.payload), equals({'statut': 'vide', 'unites_restantes': 0}));
  });

  test('chaque appel génère un id unique', () async {
    final id1 = await enqueueOperation(
      db,
      const EnqueueOp(
        type: 'soft_delete_boite',
        entityType: 'boite',
        entityId: 'a',
        payload: {},
      ),
    );
    // Léger délai pour bouger le seed du _Rand basé sur micros.
    await Future<void>.delayed(const Duration(microseconds: 1));
    final id2 = await enqueueOperation(
      db,
      const EnqueueOp(
        type: 'soft_delete_boite',
        entityType: 'boite',
        entityId: 'b',
        payload: {},
      ),
    );
    expect(id1, isNot(equals(id2)));
  });
}
