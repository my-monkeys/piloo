// Providers Riverpod CRUD boîtes via l'API + fallback offline (#18 / #56).
//
// Read : FutureProvider famille par officineId, lit directement l'API
// (pas de cache local au MVP — cf. ADR offline-first à venir).
//
// Write : tente l'API en premier. Sur DioException network (offline,
// timeout, DNS), enqueue dans pending_operations + retourne une Boite
// "optimiste" reconstituée depuis l'input. Le SyncWorker rejouera l'op
// quand le réseau revient.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart';

import 'package:piloo/shared/api/api_client_provider.dart';
import 'package:piloo/shared/db/db_provider.dart';
import 'package:piloo/shared/sync/enqueue.dart';

final boitesProvider =
    FutureProvider.family<List<Boite>, String>((ref, officineId) async {
  final api = ref.read(pilooApiClientProvider).getBoitesApi();
  final res = await api.v1OfficinesOfficineIdBoitesGet(officineId: officineId);
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('Liste boîtes : statut ${res.statusCode}');
  }
  return res.data!.items.toList();
});

/// Résultat d'une écriture qui peut avoir été soit acceptée directement
/// par l'API, soit enqueuée pour rejeu offline. La distinction permet
/// à l'UI d'adapter le message (toast "Enregistré" vs "Enregistré,
/// synchronisera plus tard").
class WriteOutcome<T> {
  const WriteOutcome({required this.value, required this.queued});
  final T value;
  /// `true` si l'op n'a pas atteint le serveur et a été enqueuée
  /// localement (le worker la rejouera).
  final bool queued;
}

/// PATCH /v1/boites/{id} : update partiel statut/stock/notes. Fallback
/// enqueue en cas d'échec réseau.
Future<WriteOutcome<Boite>> updateBoiteResult(
  WidgetRef ref, {
  required String boiteId,
  required String officineId,
  UpdateBoiteInputStatutEnum? statut,
  int? unitesInitiales,
  int? unitesRestantes,
  String? notes,
}) async {
  final api = ref.read(pilooApiClientProvider).getBoitesApi();
  final builder = UpdateBoiteInputBuilder()
    ..statut = statut
    ..unitesInitiales = unitesInitiales
    ..unitesRestantes = unitesRestantes
    ..notes = notes;
  final body = builder.build();
  try {
    final res = await api.v1BoitesIdPatch(
      id: boiteId,
      updateBoiteInput: body,
    );
    if (res.statusCode != 200 || res.data == null) {
      throw Exception('Update boîte : statut ${res.statusCode}');
    }
    ref.invalidate(boitesProvider(officineId));
    return WriteOutcome(value: res.data!, queued: false);
  } on DioException catch (e) {
    if (!_isTransient(e)) rethrow;
    await enqueueOperation(
      ref.read(localDatabaseProvider),
      EnqueueOp(
        type: 'update_boite',
        entityType: 'boite',
        entityId: boiteId,
        payload: {
          if (statut != null) 'statut': _statutToWire(statut),
          if (unitesInitiales != null) 'unites_initiales': unitesInitiales,
          if (unitesRestantes != null) 'unites_restantes': unitesRestantes,
          if (notes != null) 'notes': notes,
        },
      ),
    );
    // On retourne un placeholder en attendant le sync. L'UI doit éviter
    // de l'utiliser pour rerender (sinon l'utilisateur voit des champs
    // vides). Le toast "queued" la prévient.
    return WriteOutcome(
      value: _placeholderBoite(boiteId, officineId),
      queued: true,
    );
  }
}

/// Wrapper rétrocompatible : retourne juste la Boite (sans info queued).
/// Les callers existants n'ont pas besoin de gérer le statut offline.
Future<Boite> updateBoite(
  WidgetRef ref, {
  required String boiteId,
  required String officineId,
  UpdateBoiteInputStatutEnum? statut,
  int? unitesInitiales,
  int? unitesRestantes,
  String? notes,
}) async {
  final out = await updateBoiteResult(
    ref,
    boiteId: boiteId,
    officineId: officineId,
    statut: statut,
    unitesInitiales: unitesInitiales,
    unitesRestantes: unitesRestantes,
    notes: notes,
  );
  return out.value;
}

Future<Boite> createBoite(
  WidgetRef ref, {
  required String officineId,
  required String cip13,
  required Date peremption,
  String? lot,
  int? unitesRestantes,
  int? unitesInitiales,
  String? notes,
}) async {
  final api = ref.read(pilooApiClientProvider).getBoitesApi();
  // On instancie le builder directement plutôt que via le factory à
  // callback : sur les versions récentes de l'analyseur Dart, le
  // paramètre du callback est inféré nullable (Function<Builder?>?),
  // ce qui casse `b..field = ...` avec "receiver can be null".
  final builder = $CreateBoiteInputBuilder()
    ..cip13 = cip13
    ..peremption = peremption
    ..lot = lot
    ..unitesRestantes = unitesRestantes
    ..unitesInitiales = unitesInitiales
    ..notes = notes;
  final input = builder.build();
  try {
    final res = await api.v1OfficinesOfficineIdBoitesPost(
      officineId: officineId,
      createBoiteInput: input,
    );
    if (res.statusCode != 201 || res.data == null) {
      throw Exception('Création boîte : statut ${res.statusCode}');
    }
    ref.invalidate(boitesProvider(officineId));
    return res.data!;
  } on DioException catch (e) {
    if (!_isTransient(e)) rethrow;
    // Pour un create, l'ID serveur n'existe pas encore — on en génère
    // un côté client. Le serveur l'acceptera comme PK (UUID v4) au
    // moment du sync push (cf. /v1/sync/push qui traite operation.id
    // comme entity_id).
    final clientId = _clientUuid();
    await enqueueOperation(
      ref.read(localDatabaseProvider),
      EnqueueOp(
        type: 'create_boite',
        entityType: 'boite',
        entityId: clientId,
        payload: {
          'officine_id': officineId,
          'cip13': cip13,
          'peremption': '${peremption.year}-${peremption.month.toString().padLeft(2, '0')}-${peremption.day.toString().padLeft(2, '0')}',
          if (lot != null) 'lot': lot,
          if (unitesRestantes != null) 'unites_restantes': unitesRestantes,
          if (unitesInitiales != null) 'unites_initiales': unitesInitiales,
          if (notes != null) 'notes': notes,
        },
      ),
    );
    // Boite placeholder : l'écran qui appelle createBoite ne s'en sert
    // que pour le toast success (pas pour pré-rendre la liste — c'est
    // boitesProvider qui s'en charge). L'invalidate ne sert à rien
    // offline puisque le GET échouera aussi, mais on le déclenche au
    // cas où l'utilisateur reviendrait online entre-temps.
    return _placeholderBoite(clientId, officineId, cip13: cip13);
  }
}

/// Vrai pour les erreurs réseau (offline, timeout, DNS, conn refused).
/// Faux pour les 4xx/5xx serveur (à propager comme exception).
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

String _statutToWire(UpdateBoiteInputStatutEnum s) {
  if (s == UpdateBoiteInputStatutEnum.active) return 'active';
  if (s == UpdateBoiteInputStatutEnum.vide) return 'vide';
  if (s == UpdateBoiteInputStatutEnum.perimee) return 'perimee';
  return s.name;
}

Boite _placeholderBoite(String id, String officineId, {String? cip13}) {
  // Build minimal — les champs sont remplacés par le serveur au sync.
  // L'écran appelant ne doit pas afficher ce placeholder, il sert
  // uniquement à satisfaire la signature non-nullable du wrapper.
  final now = DateTime.now().toUtc();
  return (BoiteBuilder()
        ..id = id
        ..officineId = officineId
        ..cip13 = cip13 ?? ''
        ..peremption = Date(now.year, now.month, now.day)
        ..statut = BoiteStatutEnum.active
        ..ajouteePar = ''
        ..createdAt = now
        ..updatedAt = now)
      .build();
}

/// UUID v4 local pour les entités créées offline.
String _clientUuid() {
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
