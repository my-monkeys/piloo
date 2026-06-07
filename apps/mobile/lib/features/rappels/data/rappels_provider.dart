// Providers Riverpod CRUD rappels rapides via l'API (#98).
//
// Pas de fallback offline pour ce premier ship — les rappels sont
// configurés online uniquement. Une vraie offline-first (enqueue +
// rejeu) suivra quand le worker de sync supportera les nouvelles
// entités.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart';

import 'package:piloo/features/today/data/prises_provider.dart';
import 'package:piloo/shared/api/api_client_provider.dart';

final rappelsProvider = FutureProvider.family<List<Rappel>, String>((
  ref,
  officineId,
) async {
  final api = ref.read(pilooApiClientProvider).getRappelsApi();
  final res = await api.v1OfficinesOfficineIdRappelsGet(officineId: officineId);
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('Liste rappels : statut ${res.statusCode}');
  }
  return res.data!.items.toList();
});

/// POST /v1/officines/{id}/rappels. Pas d'enqueue offline ici (cf.
/// note module). En cas d'échec, l'exception remonte au caller qui
/// affiche le toast d'erreur.
Future<Rappel> createRappel(
  WidgetRef ref, {
  required String officineId,
  required String cip13,
  required String nomTexte,
  required Date dateDebut,
  String? unite,
  int? quantiteMatin,
  int? quantiteMidi,
  int? quantiteSoir,
  int? quantiteCoucher,
  Date? dateFin,
  String? notes,
}) async {
  final api = ref.read(pilooApiClientProvider).getRappelsApi();
  final builder = CreateRappelInputBuilder()
    ..cip13 = cip13
    ..nomTexte = nomTexte
    ..unite = unite
    ..quantiteMatin = quantiteMatin
    ..quantiteMidi = quantiteMidi
    ..quantiteSoir = quantiteSoir
    ..quantiteCoucher = quantiteCoucher
    ..dateDebut = dateDebut
    ..dateFin = dateFin
    ..notes = notes;
  final res = await api.v1OfficinesOfficineIdRappelsPost(
    officineId: officineId,
    createRappelInput: builder.build(),
  );
  if (res.statusCode != 201 || res.data == null) {
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      message: 'Création rappel : statut ${res.statusCode}',
    );
  }
  ref.invalidate(rappelsProvider(officineId));
  // Le POST /rappels génère aussi les prises pour les 30 prochains
  // jours côté serveur (#343). On invalide TOUS les jours en cache
  // pour que la timeline Aujourd'hui (et les jours déjà chargés en
  // navigation) prenne ces nouvelles prises au prochain rebuild.
  ref.invalidate(prisesDayProvider);
  return res.data!;
}

/// PATCH /v1/rappels/{id}. Invalide la liste + la timeline (les prises
/// sont régénérées côté serveur). Lève en cas d'échec.
Future<Rappel> updateRappel(
  WidgetRef ref, {
  required String id,
  required String officineId,
  String? nomTexte,
  String? unite,
  int? quantiteMatin,
  int? quantiteMidi,
  int? quantiteSoir,
  int? quantiteCoucher,
  Date? dateDebut,
  Date? dateFin,
  bool? actif,
  String? notes,
}) async {
  final api = ref.read(pilooApiClientProvider).getRappelsApi();
  final builder = UpdateRappelInputBuilder()
    ..nomTexte = nomTexte
    ..unite = unite
    ..quantiteMatin = quantiteMatin
    ..quantiteMidi = quantiteMidi
    ..quantiteSoir = quantiteSoir
    ..quantiteCoucher = quantiteCoucher
    ..dateDebut = dateDebut
    ..dateFin = dateFin
    ..actif = actif
    ..notes = notes;
  final res = await api.v1RappelsIdPatch(
    id: id,
    updateRappelInput: builder.build(),
  );
  if (res.statusCode != 200 || res.data == null) {
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      message: 'Modification rappel : statut ${res.statusCode}',
    );
  }
  ref.invalidate(rappelsProvider(officineId));
  ref.invalidate(prisesDayProvider);
  return res.data!;
}

/// Raccourci pause/réactivation d'un rappel.
Future<Rappel> toggleRappelActif(
  WidgetRef ref, {
  required String id,
  required String officineId,
  required bool actif,
}) => updateRappel(ref, id: id, officineId: officineId, actif: actif);

/// DELETE /v1/rappels/{id} (soft-delete serveur).
Future<void> deleteRappel(
  WidgetRef ref, {
  required String id,
  required String officineId,
}) async {
  final api = ref.read(pilooApiClientProvider).getRappelsApi();
  final res = await api.v1RappelsIdDelete(id: id);
  if (res.statusCode != 204 && res.statusCode != 200) {
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      message: 'Suppression rappel : statut ${res.statusCode}',
    );
  }
  ref.invalidate(rappelsProvider(officineId));
  ref.invalidate(prisesDayProvider);
}
