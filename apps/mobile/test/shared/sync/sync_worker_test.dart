// Tests du worker de sync (#91).
//
// Couvre :
//   - online → flush vide une queue de N ops
//   - offline → ne flush pas
//   - transition offline → online déclenche le flush
//   - outcome accepted → statut acked
//   - outcome rejected → statut rejected + lastError
//   - outcome transient → reste pending + retryCount incrémenté
//   - flush concurrent → un seul s'exécute, le suivant est dédupliqué
//     (et un re-fire a lieu si nouvelles ops pendant un flush en cours)
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piloo/shared/db/local_db.dart';
import 'package:piloo/shared/sync/connectivity_source.dart';
import 'package:piloo/shared/sync/ops_uploader.dart';
import 'package:piloo/shared/sync/sync_worker.dart';

class _FakeConnectivity implements ConnectivitySource {
  final _ctrl = StreamController<bool>.broadcast();

  void emit(bool online) => _ctrl.add(online);
  Future<void> close() => _ctrl.close();

  @override
  Stream<bool> get onChange => _ctrl.stream;
}

class _FakeUploader implements OpsUploader {
  _FakeUploader(this._behavior);
  final FutureOr<OpsUploadResult> Function(PendingOperationRow) _behavior;
  final List<String> seenIds = [];

  @override
  Future<OpsUploadResult> upload(PendingOperationRow op) async {
    seenIds.add(op.id);
    return _behavior(op);
  }
}

LocalDatabase _makeDb() {
  final db = LocalDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<void> _insertPending(
  LocalDatabase db, {
  required String id,
  int timestamp = 1000,
}) {
  return db.into(db.pendingOperations).insert(
        PendingOperationsCompanion.insert(
          id: id,
          type: 'create_boite',
          entityType: 'boite',
          entityId: 'b-$id',
          payload: '{}',
          timestampLocal: timestamp,
          createdAt: '2026-05-08T00:00:00Z',
          updatedAt: '2026-05-08T00:00:00Z',
        ),
      );
}

void main() {
  group('SyncWorker', () {
    test('flush vide la queue quand online', () async {
      final db = _makeDb();
      await _insertPending(db, id: 'op-1', timestamp: 100);
      await _insertPending(db, id: 'op-2', timestamp: 200);

      final connectivity = _FakeConnectivity();
      addTearDown(connectivity.close);
      final uploader = _FakeUploader(
        (_) => const OpsUploadResult(OpsUploadOutcome.accepted),
      );
      final worker = SyncWorker(
        db: db,
        connectivity: connectivity,
        uploader: uploader,
      );
      worker.start();
      addTearDown(worker.stop);

      connectivity.emit(true);
      await Future<void>.delayed(Duration.zero);
      await worker.flush();

      expect(uploader.seenIds, ['op-1', 'op-2']);
      final remaining = await (db.select(db.pendingOperations)
            ..where((o) => o.statut.equals('pending')))
          .get();
      expect(remaining, isEmpty);
      final acked = await (db.select(db.pendingOperations)
            ..where((o) => o.statut.equals('acked')))
          .get();
      expect(acked.length, 2);
    });

    test('offline ne déclenche pas de flush', () async {
      final db = _makeDb();
      await _insertPending(db, id: 'op-1');

      final connectivity = _FakeConnectivity();
      addTearDown(connectivity.close);
      final uploader = _FakeUploader(
        (_) => const OpsUploadResult(OpsUploadOutcome.accepted),
      );
      final worker = SyncWorker(
        db: db,
        connectivity: connectivity,
        uploader: uploader,
      );
      worker.start();
      addTearDown(worker.stop);

      connectivity.emit(false);
      await Future<void>.delayed(Duration.zero);

      expect(uploader.seenIds, isEmpty);
      expect(worker.isOnline, isFalse);
    });

    test('transition offline → online déclenche le flush', () async {
      final db = _makeDb();
      await _insertPending(db, id: 'op-1');

      final connectivity = _FakeConnectivity();
      addTearDown(connectivity.close);
      final uploader = _FakeUploader(
        (_) => const OpsUploadResult(OpsUploadOutcome.accepted),
      );
      final worker = SyncWorker(
        db: db,
        connectivity: connectivity,
        uploader: uploader,
      );
      worker.start();
      addTearDown(worker.stop);

      connectivity.emit(false);
      await Future<void>.delayed(Duration.zero);
      expect(uploader.seenIds, isEmpty);

      connectivity.emit(true);
      // Laisse le worker drainer le micro-task et finir flush.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(uploader.seenIds, ['op-1']);
      expect(worker.isOnline, isTrue);
    });

    test('outcome rejected → statut rejected + lastError', () async {
      final db = _makeDb();
      await _insertPending(db, id: 'op-1');

      final connectivity = _FakeConnectivity();
      addTearDown(connectivity.close);
      final uploader = _FakeUploader(
        (_) => const OpsUploadResult(
          OpsUploadOutcome.rejected,
          error: 'invalid payload',
        ),
      );
      final worker = SyncWorker(
        db: db,
        connectivity: connectivity,
        uploader: uploader,
      );
      worker.start();
      addTearDown(worker.stop);

      await worker.flush();

      final row =
          await (db.select(db.pendingOperations)..where((o) => o.id.equals('op-1')))
              .getSingle();
      expect(row.statut, 'rejected');
      expect(row.lastError, 'invalid payload');
    });

    test('outcome transient → reste pending + retryCount++', () async {
      final db = _makeDb();
      await _insertPending(db, id: 'op-1');

      final connectivity = _FakeConnectivity();
      addTearDown(connectivity.close);
      final uploader = _FakeUploader(
        (_) => const OpsUploadResult(
          OpsUploadOutcome.transient,
          error: 'timeout',
        ),
      );
      final worker = SyncWorker(
        db: db,
        connectivity: connectivity,
        uploader: uploader,
      );
      worker.start();
      addTearDown(worker.stop);

      await worker.flush();
      await worker.flush();

      final row =
          await (db.select(db.pendingOperations)..where((o) => o.id.equals('op-1')))
              .getSingle();
      expect(row.statut, 'pending');
      expect(row.retryCount, 2);
      expect(row.lastError, 'timeout');
    });

    test('flush concurrent : un seul actif, re-fire dédupliqué', () async {
      final db = _makeDb();
      await _insertPending(db, id: 'op-1', timestamp: 100);

      final connectivity = _FakeConnectivity();
      addTearDown(connectivity.close);

      final uploadStarted = Completer<void>();
      final allowFinish = Completer<void>();
      final uploader = _FakeUploader((op) async {
        if (!uploadStarted.isCompleted) uploadStarted.complete();
        await allowFinish.future;
        return const OpsUploadResult(OpsUploadOutcome.accepted);
      });

      final worker = SyncWorker(
        db: db,
        connectivity: connectivity,
        uploader: uploader,
      );
      worker.start();
      addTearDown(worker.stop);

      // 1er flush : lance et reste bloqué sur allowFinish.
      final f1 = worker.flush();
      await uploadStarted.future;

      // Pendant qu'on tient le 1er, on insère une nouvelle op et on
      // re-flush. Le worker doit dédupliquer (un seul flush actif) ET
      // re-fire à la fin pour traiter op-2.
      await _insertPending(db, id: 'op-2', timestamp: 200);
      final f2 = worker.flush();
      final f3 = worker.flush();

      allowFinish.complete();
      await Future.wait([f1, f2, f3]);

      // Les 2 ops ont fini par être uploadées. seenIds peut contenir
      // op-1 puis op-2 ; l'important : pas de double-upload de op-1.
      expect(uploader.seenIds, ['op-1', 'op-2']);
    });
  });
}
