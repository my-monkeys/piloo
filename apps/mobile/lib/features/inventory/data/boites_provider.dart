// Providers Riverpod CRUD boîtes via l'API.
//
// Volontairement très simple : un FutureProvider famille par officineId.
// Pas de cache local Drift au MVP (cf. ADR offline-first à venir). Les
// écrans appellent `ref.invalidate(boitesProvider(officineId))` après
// chaque mutation pour rafraîchir la liste.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart';

import 'package:piloo/shared/api/api_client_provider.dart';

final boitesProvider =
    FutureProvider.family<List<Boite>, String>((ref, officineId) async {
  final api = ref.read(pilooApiClientProvider).getBoitesApi();
  final res = await api.v1OfficinesOfficineIdBoitesGet(officineId: officineId);
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('Liste boîtes : statut ${res.statusCode}');
  }
  return res.data!.items.toList();
});

/// Création d'une boîte côté serveur. Wrapper qui :
///   - construit le `CreateBoiteInput` (built_value, instantiable=false →
///     on passe par la sous-classe concrète `$CreateBoiteInput`)
///   - POST via l'OpenAPI client
///   - invalide `boitesProvider(officineId)` au succès → la liste se
///     rafraîchit côté écran inventory.
///
/// Reçoit un `WidgetRef` ou `Ref` indifféremment (les deux exposent
/// `read` / `invalidate`).
/// PATCH /v1/boites/{id} : update partiel statut/stock/notes. Invalide
/// la liste de l'officine au succès. Lance une exception si l'API refuse.
Future<Boite> updateBoite(
  WidgetRef ref, {
  required String boiteId,
  required String officineId,
  UpdateBoiteInputStatutEnum? statut,
  int? unitesRestantes,
  String? notes,
}) async {
  final api = ref.read(pilooApiClientProvider).getBoitesApi();
  final builder = UpdateBoiteInputBuilder()
    ..statut = statut
    ..unitesRestantes = unitesRestantes
    ..notes = notes;
  final res = await api.v1BoitesIdPatch(
    id: boiteId,
    updateBoiteInput: builder.build(),
  );
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('Update boîte : statut ${res.statusCode}');
  }
  ref.invalidate(boitesProvider(officineId));
  return res.data!;
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
  final res = await api.v1OfficinesOfficineIdBoitesPost(
    officineId: officineId,
    createBoiteInput: input,
  );
  if (res.statusCode != 201 || res.data == null) {
    throw Exception('Création boîte : statut ${res.statusCode}');
  }
  ref.invalidate(boitesProvider(officineId));
  return res.data!;
}
