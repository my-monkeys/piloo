// Tests du handler d'actions rapides notification prise (#128).
//
// On instancie le LocalDatabase en mémoire (`forTesting`) puis on simule
// un NotificationResponse via le constructor public. On vérifie qu'une
// op `update_prise` correcte est insérée dans `pending_operations` ET
// que le miroir local `prises_planifiees` reflète le nouvel état.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/shared/db/local_db.dart';
import 'package:piloo/shared/notifications/prise_action_handler.dart';

void main() {
  late LocalDatabase db;
  const priseId = 'b6f1c0ee-0d4a-4ac5-8901-6f4dafe6b6c2';
  final originalDt = DateTime.utc(2026, 5, 20, 12, 0);

  setUp(() async {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
    // Mirror local — pour vérifier la mise à jour optimiste.
    await db.into(db.prisesPlanifiees).insert(
          PrisesPlanifieesCompanion.insert(
            id: priseId,
            prescriptionId: 'presc-1',
            officineId: 'off-1',
            datetimePrevue: originalDt.toIso8601String(),
            createdAt: '2026-05-20T10:00:00Z',
            updatedAt: '2026-05-20T10:00:00Z',
            statut: const Value('prevue'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  NotificationResponse mkResponse(String actionId) {
    return NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotificationAction,
      actionId: actionId,
      payload: jsonEncode({'priseId': priseId, 'dt': originalDt.toIso8601String()}),
      id: 1,
      input: null,
    );
  }

  Future<Map<String, dynamic>> firstPendingPayload() async {
    final ops = await db.select(db.pendingOperations).get();
    expect(ops, hasLength(1));
    return jsonDecode(ops.first.payload) as Map<String, dynamic>;
  }

  test('action "Prise" enqueue update_prise statut=prise + miroir local', () async {
    await applyPriseActionForTest(db, mkResponse(priseActionMarkPrise));
    expect(await firstPendingPayload(), {'statut': 'prise'});
    final row = await (db.select(db.prisesPlanifiees)..where((t) => t.id.equals(priseId))).getSingle();
    expect(row.statut, 'prise');
    expect(row.datetimeValidation, isNotNull);
  });

  test('action "Sauter" enqueue update_prise statut=sautee + miroir local', () async {
    await applyPriseActionForTest(db, mkResponse(priseActionMarkSautee));
    expect(await firstPendingPayload(), {'statut': 'sautee'});
    final row = await (db.select(db.prisesPlanifiees)..where((t) => t.id.equals(priseId))).getSingle();
    expect(row.statut, 'sautee');
  });

  test('action "+15min" enqueue update_prise datetime + miroir local', () async {
    await applyPriseActionForTest(db, mkResponse(priseActionSnooze15));
    final payload = await firstPendingPayload();
    final newDt = DateTime.parse(payload['datetime_prevue'] as String);
    expect(newDt, originalDt.add(const Duration(minutes: 15)));
    final row = await (db.select(db.prisesPlanifiees)..where((t) => t.id.equals(priseId))).getSingle();
    expect(DateTime.parse(row.datetimePrevue), newDt);
  });

  test('payload legacy "prise:<id>" toléré (rétrocompat) sans dt → snooze no-op', () async {
    final response = NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotificationAction,
      actionId: priseActionSnooze15,
      payload: 'prise:$priseId',
      id: 1,
      input: null,
    );
    await applyPriseActionForTest(db, response);
    // Pas de dt = on n'enqueue pas (silencieux plutôt qu'horaire faux).
    final ops = await db.select(db.pendingOperations).get();
    expect(ops, isEmpty);
  });

  test('action inconnue ignorée', () async {
    await applyPriseActionForTest(db, mkResponse('unknown_action'));
    final ops = await db.select(db.pendingOperations).get();
    expect(ops, isEmpty);
  });
}
