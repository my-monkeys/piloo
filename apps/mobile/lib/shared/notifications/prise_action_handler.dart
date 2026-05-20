// Handler des actions rapides de notification prise (#128).
//
// Le handler est appelé par flutter_local_notifications quand l'utilisateur
// tape un bouton d'action sur la notification — y compris quand l'app est
// tuée (Flutter ré-instancie un isolate Dart pour exécuter ce callback).
//
// Contraintes :
//   - Top-level fonction + `@pragma('vm:entry-point')` (sinon tree-shaking
//     l'élimine en release).
//   - On n'a accès à AUCUN provider Riverpod ici (isolate séparé). Pour
//     écrire, on ré-ouvre Drift en direct.
//   - On écrit dans `pending_operations` (offline-first) ET on met à jour
//     le miroir local `prises_planifiees` si présent — comme ça le user
//     voit l'état correct la prochaine fois qu'il ouvre l'app, même si
//     la sync n'a pas encore tourné.
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:piloo/shared/db/local_db.dart';

const String priseActionMarkPrise = 'mark_prise';
const String priseActionMarkSautee = 'mark_sautee';
const String priseActionSnooze15 = 'snooze_15';

@pragma('vm:entry-point')
Future<void> handlePriseActionBackground(NotificationResponse response) async {
  final actionId = response.actionId;
  final rawPayload = response.payload;
  if (actionId == null || rawPayload == null || rawPayload.isEmpty) return;

  final decoded = _parsePayload(rawPayload);
  final priseId = decoded.priseId;
  if (priseId == null) return;

  final db = LocalDatabase();
  try {
    await _applyAction(db, actionId: actionId, priseId: priseId, originalDt: decoded.originalDt);
  } finally {
    await db.close();
  }
}

/// Variante test-only : utilise une DB déjà ouverte (in-memory) au lieu
/// d'instancier LocalDatabase() — évite le binding plugin path_provider.
@visibleForTesting
Future<void> applyPriseActionForTest(LocalDatabase db, NotificationResponse response) async {
  final actionId = response.actionId;
  final rawPayload = response.payload;
  if (actionId == null || rawPayload == null || rawPayload.isEmpty) return;
  final decoded = _parsePayload(rawPayload);
  final priseId = decoded.priseId;
  if (priseId == null) return;
  await _applyAction(db, actionId: actionId, priseId: priseId, originalDt: decoded.originalDt);
}

Future<void> _applyAction(
  LocalDatabase db, {
  required String actionId,
  required String priseId,
  required DateTime? originalDt,
}) async {
  final nowIso = DateTime.now().toUtc().toIso8601String();
  switch (actionId) {
    case priseActionMarkPrise:
      await _enqueue(db, priseId, {'statut': 'prise'});
      await _updateLocalStatut(db, priseId, 'prise', nowIso);
    case priseActionMarkSautee:
      await _enqueue(db, priseId, {'statut': 'sautee'});
      await _updateLocalStatut(db, priseId, 'sautee', nowIso);
    case priseActionSnooze15:
      // Sans datetime d'origine on ne peut pas calculer "+15min" de manière
      // fiable (le row local n'est pas toujours présent — la timeline du jour
      // vient du serveur sans mirror systématique). On préfère no-op silencieux
      // que d'écrire un horaire faux.
      if (originalDt == null) return;
      final newDt = originalDt.add(const Duration(minutes: 15)).toUtc();
      await _enqueue(db, priseId, {'datetime_prevue': newDt.toIso8601String()});
      await _updateLocalDatetime(db, priseId, newDt.toIso8601String(), nowIso);
    default:
      return;
  }
}

Future<void> _enqueue(LocalDatabase db, String priseId, Map<String, dynamic> payload) async {
  await db.into(db.pendingOperations).insert(
        PendingOperationsCompanion(
          id: Value(_uuidV4()),
          type: const Value('update_prise'),
          entityType: const Value('prise_planifiee'),
          entityId: Value(priseId),
          payload: Value(jsonEncode(payload)),
          timestampLocal: Value(DateTime.now().millisecondsSinceEpoch),
          createdAt: Value(DateTime.now().toUtc().toIso8601String()),
          updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
        ),
      );
}

Future<void> _updateLocalStatut(LocalDatabase db, String priseId, String statut, String nowIso) async {
  await (db.update(db.prisesPlanifiees)..where((t) => t.id.equals(priseId))).write(
    PrisesPlanifieesCompanion(
      statut: Value(statut),
      datetimeValidation: Value(nowIso),
      updatedAt: Value(nowIso),
    ),
  );
}

Future<void> _updateLocalDatetime(LocalDatabase db, String priseId, String newDtIso, String nowIso) async {
  await (db.update(db.prisesPlanifiees)..where((t) => t.id.equals(priseId))).write(
    PrisesPlanifieesCompanion(
      datetimePrevue: Value(newDtIso),
      updatedAt: Value(nowIso),
    ),
  );
}

class _DecodedPayload {
  const _DecodedPayload({this.priseId, this.originalDt});
  final String? priseId;
  final DateTime? originalDt;
}

_DecodedPayload _parsePayload(String raw) {
  // Format actuel (#128) : JSON {priseId, dt}. Legacy `prise:<id>` toléré
  // au cas où une notif planifiée avant le déploiement #128 est délivrée.
  if (raw.startsWith('{')) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final priseId = map['priseId'] as String?;
      final dtRaw = map['dt'] as String?;
      final dt = dtRaw != null ? DateTime.tryParse(dtRaw) : null;
      return _DecodedPayload(priseId: priseId, originalDt: dt);
    } catch (_) {
      return const _DecodedPayload();
    }
  }
  if (raw.startsWith('prise:')) {
    return _DecodedPayload(priseId: raw.substring(6));
  }
  return const _DecodedPayload();
}

/// UUID v4 minimal — dupliqué pour éviter d'importer enqueue.dart (qui
/// dépend de Riverpod via d'autres imports transitifs et casse en isolate).
String _uuidV4() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int i) => i.toRadixString(16).padLeft(2, '0');
  final s = bytes.map(hex).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}
