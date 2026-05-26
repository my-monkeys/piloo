// Provider Riverpod des prises d'un jour pour une officine donnée.
//
// Pattern stale-while-revalidate : émet d'abord les données en cache
// local (SQLite via api_cache) pour un affichage instantané, puis
// fetch le réseau en arrière-plan et émet la réponse fraîche.
//
// Lit GET /v1/prises?officine_id=...&date=YYYY-MM-DD (#114).
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/features/onboarding/data/demo_fixtures.dart';
import 'package:piloo/features/onboarding/data/demo_mode_provider.dart';
import 'package:piloo/shared/api/api_client_provider.dart';
import 'package:piloo/shared/db/api_cache.dart';
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
    StreamProvider.family<List<api.PriseTimelineItem>, PrisesDayKey>(
  (ref, key) async* {
    if (isDemoMode(ref)) {
      final today = isoDate(DateTime.now());
      yield key.date == today ? demoPrisesToday() : const [];
      return;
    }

    final cache = ApiCacheRepo(ref.read(localDatabaseProvider));
    final cacheKey = 'prises:${key.officineId}:${key.date}';

    // 1) Émet le cache immédiatement s'il existe.
    final cached = await cache.get(cacheKey);
    List<api.PriseTimelineItem>? cachedItems;
    if (cached != null) {
      try {
        cachedItems = _deserializePrises(cached);
        yield cachedItems;
      } catch (_) {
        // Cache corrompu — on l'ignore et on attend le réseau.
        await cache.invalidate(cacheKey);
      }
    }

    // 2) Fetch réseau en parallèle (ou comme seule source si pas de cache).
    try {
      final items = await _fetchFromApi(ref, key);
      await cache.put(cacheKey, _serializePrises(items));
      yield items;
    } catch (e) {
      if (cachedItems != null) return;
      rethrow;
    }
  },
);

Future<List<api.PriseTimelineItem>> _fetchFromApi(
  Ref ref,
  PrisesDayKey key,
) async {
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
  if (key.date == isoDate(DateTime.now())) {
    // ignore: unawaited_futures
    ref.read(notificationsServiceProvider).scheduleForPrises(items);
  }
  return items;
}

String _serializePrises(List<api.PriseTimelineItem> items) {
  final list = items
      .map((item) => api.standardSerializers.serializeWith(
            api.PriseTimelineItem.serializer,
            item,
          ))
      .toList();
  return jsonEncode(list);
}

List<api.PriseTimelineItem> _deserializePrises(String json) {
  final decoded = jsonDecode(json) as List<dynamic>;
  return decoded
      .map((e) => api.standardSerializers.deserializeWith(
            api.PriseTimelineItem.serializer,
            e,
          )!)
      .toList();
}

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
  // ignore: unawaited_futures
  ref.read(notificationsServiceProvider).cancelForPrise(priseId);
  // Invalide le cache local + le provider pour forcer un re-fetch.
  final cache = ApiCacheRepo(ref.read(localDatabaseProvider));
  await cache.invalidate('prises:$officineId:$date');
  ref.invalidate(
    prisesDayProvider(PrisesDayKey(officineId: officineId, date: date)),
  );
}

/// PATCH /v1/prises/{id} avec un nouvel horaire prévu (#120).
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
  // ignore: unawaited_futures
  ref.read(notificationsServiceProvider).cancelForPrise(priseId);
  final cache = ApiCacheRepo(ref.read(localDatabaseProvider));
  await cache.invalidate('prises:$officineId:$date');
  ref.invalidate(
    prisesDayProvider(PrisesDayKey(officineId: officineId, date: date)),
  );
}

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
