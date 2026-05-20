// Helper d'enqueue dans `pending_operations` (#56, follow-up #18).
//
// Sert de fallback aux writes API quand le réseau échoue. L'op
// enregistrée sera rejouée par SyncWorker quand la connectivité
// revient (cf. sync_worker.dart + sync_providers.dart).
//
// Convention payload : on stocke le body JSON tel qu'il serait envoyé
// à l'API REST, c'est-à-dire le shape attendu par `SyncOperation`
// côté serveur (cf. packages/api-contract/src/schemas/sync.ts).
//
// `entity_id` : pour un `create_*`, c'est l'UUID v4 généré côté client
// (cohérent avec offline-first — on n'attend pas le serveur pour avoir
// un id). Pour `update_*` / `soft_delete_*`, c'est l'id serveur.
import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:piloo/shared/db/local_db.dart';

class EnqueueOp {
  const EnqueueOp({
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.payload,
  });

  /// Type SyncOperation : `create_boite` | `update_boite` |
  /// `soft_delete_boite`. À étendre quand d'autres entités sont
  /// supportées côté serveur.
  final String type;
  /// `boite` aujourd'hui. Mappable 1:1 sur les noms côté API.
  final String entityType;
  final String entityId;
  /// Body JSON sérialisable. La couche appelante construit la map
  /// (clé snake_case, conforme schéma serveur).
  final Map<String, dynamic> payload;
}

/// Insère une op dans pending_operations avec statut `pending`. ID
/// auto-généré UUID v4. Idempotent par construction : si l'écran rejoue
/// l'action (ex: tap retry), une nouvelle ligne est créée — le serveur
/// dédupliquera via `client_id + operation_id`.
Future<String> enqueueOperation(LocalDatabase db, EnqueueOp op) async {
  final id = _uuidV4();
  final now = DateTime.now().toUtc().toIso8601String();
  await db.into(db.pendingOperations).insert(
        PendingOperationsCompanion(
          id: Value(id),
          type: Value(op.type),
          entityType: Value(op.entityType),
          entityId: Value(op.entityId),
          payload: Value(jsonEncode(op.payload)),
          timestampLocal: Value(DateTime.now().millisecondsSinceEpoch),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
  return id;
}

/// Génère un UUID v4 sans dépendance externe (RFC 4122 §4.4).
/// Dupliqué depuis sync_providers.dart pour éviter d'exporter un helper
/// privé — l'usage est trop ciblé pour mériter un module dédié.
String _uuidV4() {
  final r = _Rand();
  final bytes = List<int>.generate(16, (_) => r.next() & 0xFF);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int i) => i.toRadixString(16).padLeft(2, '0');
  final s = bytes.map(hex).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

class _Rand {
  int _state = DateTime.now().microsecondsSinceEpoch;
  int next() {
    var x = _state;
    x ^= x << 13;
    x &= 0xFFFFFFFFFFFFFFFF;
    x ^= x >> 7;
    x ^= x << 17;
    x &= 0xFFFFFFFFFFFFFFFF;
    _state = x;
    return x & 0xFFFFFFFF;
  }
}
