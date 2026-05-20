// Provider Riverpod des prises d'un jour pour une officine donnée.
//
// Lit GET /v1/prises?officine_id=...&date=YYYY-MM-DD (#114).
// Le format `date` attendu est YYYY-MM-DD strict — pas de DateTime.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/shared/api/api_client_provider.dart';
import 'package:piloo/shared/db/db_provider.dart';
import 'package:piloo/shared/notifications/notifications_service.dart';
import 'package:piloo/shared/sync/enqueue.dart';

class PrisesDayKey {
  const PrisesDayKey({required this.officineId, required this.date});

  final String officineId;
  /// YYYY-MM-DD (UTC date).
  final String date;

  @override
  bool operator ==(Object other) =>
      other is PrisesDayKey && other.officineId == officineId && other.date == date;
  @override
  int get hashCode => Object.hash(officineId, date);
}

final prisesDayProvider =
    FutureProvider.family<List<api.PriseTimelineItem>, PrisesDayKey>(
  (ref, key) async {
    final client = ref.read(pilooApiClientProvider).getPrisesApi();
    final parts = key.date.split('-').map(int.parse).toList(growable: false);
    final res = await client.v1PrisesGet(
      officineId: key.officineId,
      date: api.Date(parts[0], parts[1], parts[2]),
    );
    if (res.statusCode != 200 || res.data == null) {
      throw Exception('GET /v1/prises : statut ${res.statusCode}');
    }
    final items = res.data!.items.toList();
    // Replanifie les notifs locales uniquement pour la query "aujourd'hui"
    // — la timeline future est consultative, on ne veut pas spammer
    // l'utilisateur avec des rappels J+15.
    if (key.date == isoDate(DateTime.now())) {
      // fire-and-forget : ne bloque pas la chaîne de chargement.
      // Ignorer l'erreur car les permissions OS peuvent être refusées.
      // ignore: unawaited_futures
      ref.read(notificationsServiceProvider).scheduleForPrises(items);
    }
    return items;
  },
);

/// Helper YYYY-MM-DD UTC d'un DateTime.
String isoDate(DateTime d) {
  final u = d.toUtc();
  final y = u.year.toString().padLeft(4, '0');
  final m = u.month.toString().padLeft(2, '0');
  final day = u.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// PATCH /v1/prises/{id} avec un nouveau statut. Invalide la query
/// du jour concerné pour rafraîchir la liste immédiatement. Fallback
/// enqueue dans pending_operations si le réseau est down (#56/#57).
Future<void> updatePriseStatut(
  WidgetRef ref, {
  required String priseId,
  required String officineId,
  required String date,
  required api.UpdatePriseInputStatutEnum statut,
}) async {
  final client = ref.read(pilooApiClientProvider).getPrisesApi();
  final builder = api.UpdatePriseInputBuilder()..statut = statut;
  try {
    final res = await client.v1PrisesIdPatch(
      id: priseId,
      updatePriseInput: builder.build(),
    );
    if (res.statusCode != 200 || res.data == null) {
      throw Exception('PATCH /v1/prises/{id} : statut ${res.statusCode}');
    }
  } on DioException catch (e) {
    if (!_isTransient(e)) rethrow;
    await enqueueOperation(
      ref.read(localDatabaseProvider),
      EnqueueOp(
        type: 'update_prise',
        entityType: 'prise',
        entityId: priseId,
        payload: {'statut': _statutToWire(statut)},
      ),
    );
  }
  // Annule la notif locale associée — la prise n'a plus besoin de
  // rappel puisqu'elle vient d'être validée/sautée (ou queue de l'être).
  // ignore: unawaited_futures
  ref.read(notificationsServiceProvider).cancelForPrise(priseId);
  ref.invalidate(
    prisesDayProvider(PrisesDayKey(officineId: officineId, date: date)),
  );
}

/// PATCH /v1/prises/{id} avec un nouvel horaire prévu (#120). Sert
/// au tap long pour déplacer ponctuellement une prise. Fallback
/// enqueue offline (#57).
Future<void> updatePriseDatetime(
  WidgetRef ref, {
  required String priseId,
  required String officineId,
  required String date,
  required DateTime datetimePrevue,
}) async {
  final client = ref.read(pilooApiClientProvider).getPrisesApi();
  final utc = datetimePrevue.toUtc();
  final builder = api.UpdatePriseInputBuilder()..datetimePrevue = utc;
  try {
    final res = await client.v1PrisesIdPatch(
      id: priseId,
      updatePriseInput: builder.build(),
    );
    if (res.statusCode != 200 || res.data == null) {
      throw Exception('PATCH /v1/prises/{id} : statut ${res.statusCode}');
    }
  } on DioException catch (e) {
    if (!_isTransient(e)) rethrow;
    await enqueueOperation(
      ref.read(localDatabaseProvider),
      EnqueueOp(
        type: 'update_prise',
        entityType: 'prise',
        entityId: priseId,
        payload: {'datetime_prevue': utc.toIso8601String()},
      ),
    );
  }
  // Annule la notif locale et laisse `scheduleForPrises` (déclenché
  // par invalidate) reposer la notification au nouveau créneau.
  // ignore: unawaited_futures
  ref.read(notificationsServiceProvider).cancelForPrise(priseId);
  ref.invalidate(
    prisesDayProvider(PrisesDayKey(officineId: officineId, date: date)),
  );
}

/// Vrai pour les erreurs réseau (offline, timeout, DNS, conn refused).
/// Faux pour les 4xx/5xx serveur (à propager comme exception).
/// Aligné sur boites_provider._isTransient — dupliqué localement pour
/// éviter une dépendance croisée entre features.
bool _isTransient(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      return true;
    case DioExceptionType.badResponse:
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
      return false;
  }
}

String _statutToWire(api.UpdatePriseInputStatutEnum s) {
  if (s == api.UpdatePriseInputStatutEnum.prise) return 'prise';
  if (s == api.UpdatePriseInputStatutEnum.sautee) return 'sautee';
  if (s == api.UpdatePriseInputStatutEnum.prevue) return 'prevue';
  return s.name;
}
