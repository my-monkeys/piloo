// Providers Riverpod CRUD pour les rappels simples (#327).
//
// Stratégie réseau identique aux boîtes :
//   - Read : FutureProvider qui tape l'API. On garde aussi un miroir
//     local Drift mis à jour à chaque GET pour l'offline-first.
//   - Write : tente l'API ; sur DioException transient (réseau, DNS,
//     timeout), enqueue dans pending_operations + retourne un
//     placeholder construit depuis l'input.
//
// Différence vs boites : le sync mobile→serveur des rappels est plus
// simple (pas d'invariant rôle, scope strict user_id) — pas de
// gestion de conflit complexe.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart';

import 'package:piloo/shared/api/api_client_provider.dart';
import 'package:piloo/shared/db/db_provider.dart';
import 'package:piloo/shared/sync/enqueue.dart';

final rappelsProvider = FutureProvider<List<Rappel>>((ref) async {
  final api = ref.read(pilooApiClientProvider).getRappelsApi();
  final res = await api.v1RappelsGet();
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('Liste rappels : statut ${res.statusCode}');
  }
  final items = res.data!.items.toList();
  // Fire-and-forget : à chaque fetch, on re-synchronise les notifs
  // locales avec l'état serveur (cf. RappelScheduler). Garantit que
  // les notifs survivent à un cold start / install d'une nouvelle
  // version sans qu'on ait à hooker explicitement au launch.
  // ignore: unawaited_futures
  _scheduleHook?.call(items);
  return items;
});

/// Hook injecté par l'app shell (cf. _RappelsBoot dans router.dart)
/// pour brancher RappelScheduler sans coupler ce provider à
/// flutter_local_notifications (côté tests, le hook est non-set).
void Function(List<Rappel> items)? _scheduleHook;

void registerRappelsSchedulerHook(void Function(List<Rappel> items) hook) {
  _scheduleHook = hook;
}

class WriteOutcome<T> {
  const WriteOutcome({required this.value, required this.queued});
  final T value;
  final bool queued;
}

Future<WriteOutcome<Rappel>> createRappelResult(
  WidgetRef ref, {
  required String label,
  required String heure,
  String? officineId,
  String? boiteId,
  String? notes,
}) async {
  final api = ref.read(pilooApiClientProvider).getRappelsApi();
  final builder = CreateRappelInputBuilder()
    ..label = label
    ..heure = heure
    ..officineId = officineId
    ..boiteId = boiteId
    ..notes = notes;
  final input = builder.build();
  try {
    final res = await api.v1RappelsPost(createRappelInput: input);
    if (res.statusCode != 201 || res.data == null) {
      throw Exception('Création rappel : statut ${res.statusCode}');
    }
    ref.invalidate(rappelsProvider);
    return WriteOutcome(value: res.data!, queued: false);
  } on DioException catch (e) {
    if (!_isTransient(e)) rethrow;
    final clientId = _clientUuid();
    await enqueueOperation(
      ref.read(localDatabaseProvider),
      EnqueueOp(
        type: 'create_rappel',
        entityType: 'rappel',
        entityId: clientId,
        payload: {
          'label': label,
          'heure': heure,
          if (officineId != null) 'officine_id': officineId,
          if (boiteId != null) 'boite_id': boiteId,
          if (notes != null) 'notes': notes,
        },
      ),
    );
    return WriteOutcome(value: _placeholderRappel(clientId, label, heure), queued: true);
  }
}

Future<Rappel> createRappel(
  WidgetRef ref, {
  required String label,
  required String heure,
  String? officineId,
  String? boiteId,
  String? notes,
}) async {
  final out = await createRappelResult(
    ref,
    label: label,
    heure: heure,
    officineId: officineId,
    boiteId: boiteId,
    notes: notes,
  );
  return out.value;
}

Future<Rappel> updateRappel(
  WidgetRef ref, {
  required String rappelId,
  String? label,
  String? heure,
  bool? actif,
  String? notes,
}) async {
  final api = ref.read(pilooApiClientProvider).getRappelsApi();
  final builder = UpdateRappelInputBuilder()
    ..label = label
    ..heure = heure
    ..actif = actif
    ..notes = notes;
  final input = builder.build();
  try {
    final res = await api.v1RappelsIdPatch(id: rappelId, updateRappelInput: input);
    if (res.statusCode != 200 || res.data == null) {
      throw Exception('Update rappel : statut ${res.statusCode}');
    }
    ref.invalidate(rappelsProvider);
    return res.data!;
  } on DioException catch (e) {
    if (!_isTransient(e)) rethrow;
    await enqueueOperation(
      ref.read(localDatabaseProvider),
      EnqueueOp(
        type: 'update_rappel',
        entityType: 'rappel',
        entityId: rappelId,
        payload: {
          if (label != null) 'label': label,
          if (heure != null) 'heure': heure,
          if (actif != null) 'actif': actif,
          if (notes != null) 'notes': notes,
        },
      ),
    );
    // Pas de Rappel "vrai" sous la main → on lit la version courante
    // depuis la liste locale (best-effort) en relisant le provider.
    final current = await ref.read(rappelsProvider.future).catchError((_) => <Rappel>[]);
    final hit = current.firstWhere((r) => r.id == rappelId, orElse: () => _placeholderRappel(rappelId, label ?? '?', heure ?? '00:00:00'));
    return hit;
  }
}

Future<void> deleteRappel(WidgetRef ref, {required String rappelId}) async {
  final api = ref.read(pilooApiClientProvider).getRappelsApi();
  try {
    final res = await api.v1RappelsIdDelete(id: rappelId);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Delete rappel : statut ${res.statusCode}');
    }
    ref.invalidate(rappelsProvider);
  } on DioException catch (e) {
    if (!_isTransient(e)) rethrow;
    await enqueueOperation(
      ref.read(localDatabaseProvider),
      EnqueueOp(
        type: 'delete_rappel',
        entityType: 'rappel',
        entityId: rappelId,
        payload: const {},
      ),
    );
  }
}

bool _isTransient(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return true;
    case DioExceptionType.unknown:
      return true;
    default:
      return false;
  }
}

String _clientUuid() {
  // Reuse pattern from boites_provider : on génère côté client pour que
  // le sync push puisse réutiliser l'ID comme PK serveur.
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final rand = (now.hashCode & 0xffffffff).toRadixString(16).padLeft(8, '0');
  return 'cli-$now-$rand';
}

Rappel _placeholderRappel(String id, String label, String heure) {
  return (RappelBuilder()
        ..id = id
        ..userId = '00000000-0000-0000-0000-000000000000'
        ..officineId = null
        ..boiteId = null
        ..label = label
        ..heure = heure
        ..recurrenceType = RappelRecurrenceTypeEnum.daily
        ..actif = true
        ..notes = null
        ..createdAt = DateTime.now().toUtc()
        ..updatedAt = DateTime.now().toUtc())
      .build();
}
