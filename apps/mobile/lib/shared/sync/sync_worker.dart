// Worker de synchronisation push (#91).
//
// Rôle : quand la connectivité revient, lire toutes les ops `pending`
// dans la table `pending_operations` (cf. #47/#90) et les envoyer au
// serveur via `OpsUploader`. Met à jour le statut selon le résultat
// (`acked` / `rejected` / reste `pending` avec retry_count++).
//
// Anti-tempête : un seul `flush()` à la fois (lock interne). Si une
// nouvelle transition online → online survient pendant un flush, on
// re-flush à la fin (un follow-up suffit, pas d'accumulation).
//
// Le worker n'écoute pas les nouvelles écritures locales : c'est le
// rôle de l'appelant d'invoquer `flush()` après chaque opération
// (ex: depuis le repository qui ajoute la ligne `pending_operations`).
// Cette séparation évite un trigger Drift transverse qui complique les
// tests. Le worker garantit juste : "online ⇒ on tente d'écouler".
import 'dart:async';

import 'package:drift/drift.dart';

import 'package:piloo/shared/db/local_db.dart';
import 'package:piloo/shared/sync/connectivity_source.dart';
import 'package:piloo/shared/sync/ops_uploader.dart';

class SyncWorker {
  SyncWorker({
    required LocalDatabase db,
    required ConnectivitySource connectivity,
    required OpsUploader uploader,
    DateTime Function() now = _defaultNow,
  })  : _db = db,
        _connectivity = connectivity,
        _uploader = uploader,
        _now = now;

  static DateTime _defaultNow() => DateTime.now().toUtc();

  final LocalDatabase _db;
  final ConnectivitySource _connectivity;
  final OpsUploader _uploader;
  final DateTime Function() _now;

  StreamSubscription<bool>? _sub;
  bool _flushing = false;
  bool _refireNeeded = false;
  bool _online = false;

  void start() {
    _sub ??= _connectivity.onChange.listen((online) {
      _online = online;
      if (online) {
        // ignore: discarded_futures
        flush();
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  bool get isOnline => _online;

  /// Tente d'envoyer toutes les ops `pending`. Si déjà en cours, marque
  /// qu'un re-fire est nécessaire et retourne immédiatement.
  Future<void> flush() async {
    if (_flushing) {
      _refireNeeded = true;
      return;
    }
    _flushing = true;
    try {
      do {
        _refireNeeded = false;
        await _flushOnce();
      } while (_refireNeeded);
    } finally {
      _flushing = false;
    }
  }

  Future<void> _flushOnce() async {
    final ops = await (_db.select(_db.pendingOperations)
          ..where((o) => o.statut.equals('pending'))
          ..orderBy([(o) => OrderingTerm(expression: o.timestampLocal)]))
        .get();

    for (final op in ops) {
      final result = await _uploader.upload(op);
      await _applyResult(op, result);
    }
  }

  Future<void> _applyResult(
    PendingOperationRow op,
    OpsUploadResult result,
  ) async {
    final updatedAt = _now().toIso8601String();
    final query = _db.update(_db.pendingOperations)
      ..where((o) => o.id.equals(op.id));
    switch (result.outcome) {
      case OpsUploadOutcome.accepted:
        await query.write(PendingOperationsCompanion(
          statut: const Value('acked'),
          updatedAt: Value(updatedAt),
        ));
      case OpsUploadOutcome.rejected:
        await query.write(PendingOperationsCompanion(
          statut: const Value('rejected'),
          lastError: Value(result.error),
          updatedAt: Value(updatedAt),
        ));
      case OpsUploadOutcome.transient:
        await query.write(PendingOperationsCompanion(
          retryCount: Value(op.retryCount + 1),
          lastError: Value(result.error),
          updatedAt: Value(updatedAt),
        ));
    }
  }
}
