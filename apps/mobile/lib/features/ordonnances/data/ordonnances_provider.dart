// Providers Riverpod ordonnances (liste + détail + édition + duplication).
import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/features/today/data/prises_provider.dart';
import 'package:piloo/shared/api/api_client_provider.dart';

final ordonnancesProvider =
    FutureProvider.family<List<api.Ordonnance>, String>((ref, officineId) async {
  final client = ref.read(pilooApiClientProvider).getOrdonnancesApi();
  final res = await client.v1OfficinesOfficineIdOrdonnancesGet(
    officineId: officineId,
  );
  if (res.statusCode != 200 || res.data == null) {
    throw Exception(
      'GET /v1/officines/$officineId/ordonnances : ${res.statusCode}',
    );
  }
  return res.data!.items.toList();
});

final ordonnanceDetailProvider =
    FutureProvider.family<api.OrdonnanceWithPrescriptions, String>(
        (ref, ordonnanceId) async {
  final client = ref.read(pilooApiClientProvider).getOrdonnancesApi();
  final res = await client.v1OrdonnancesIdGet(id: ordonnanceId);
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('GET /v1/ordonnances/$ordonnanceId : ${res.statusCode}');
  }
  return res.data!;
});

/// PATCH /v1/ordonnances/{id} avec les champs modifiables.
Future<api.Ordonnance> updateOrdonnance(
  WidgetRef ref, {
  required String ordonnanceId,
  String? prescripteur,
  api.Date? datePrescription,
  String? notes,
}) async {
  final client = ref.read(pilooApiClientProvider).getOrdonnancesApi();
  final builder = api.UpdateOrdonnanceInputBuilder()
    ..prescripteur = prescripteur
    ..datePrescription = datePrescription
    ..notes = notes;
  final res = await client.v1OrdonnancesIdPatch(
    id: ordonnanceId,
    updateOrdonnanceInput: builder.build(),
  );
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('PATCH /v1/ordonnances/$ordonnanceId : ${res.statusCode}');
  }
  ref.invalidate(ordonnanceDetailProvider(ordonnanceId));
  // La liste affiche prescripteur + date — invalider toute l'officine
  // serait excessif, mais on n'a pas l'officineId ici sans re-fetch.
  // Le caller doit invalider ordonnancesProvider(officineId) lui-même.
  return res.data!;
}

/// Duplique une ordonnance existante : nouvelle entrée datée aujourd'hui,
/// avec les mêmes prescriptions (même posologie, mêmes médocs). Sert
/// pour les ordonnances renouvelées à l'identique chez le même
/// prescripteur (cas fréquent en maladie chronique).
Future<api.OrdonnanceWithPrescriptions> duplicateOrdonnance(
  WidgetRef ref, {
  required api.OrdonnanceWithPrescriptions source,
  required String officineId,
}) async {
  final client = ref.read(pilooApiClientProvider).getOrdonnancesApi();
  final now = DateTime.now();
  final prescriptions = source.prescriptions.map((p) =>
      (api.CreatePrescriptionInputBuilder()
            ..cip13 = p.cip13
            ..cis = p.cis
            ..nomTexte = p.nomTexte
            ..posologie = p.posologie.toBuilder()
            ..dureeJours = p.dureeJours
            ..indication = p.indication
            ..notes = p.notes)
          .build());
  final input = (api.CreateOrdonnanceInputBuilder()
        ..prescripteur = source.prescripteur
        ..datePrescription = api.Date(now.year, now.month, now.day)
        ..source_ = api.CreateOrdonnanceInputSource_Enum.manuelle
        ..notes = source.notes
        ..prescriptions = ListBuilder<api.CreatePrescriptionInput>(prescriptions))
      .build();
  final res = await client.v1OfficinesOfficineIdOrdonnancesPost(
    officineId: officineId,
    createOrdonnanceInput: input,
  );
  if (res.statusCode != 201 || res.data == null) {
    throw Exception('POST ordonnances (duplicate) : ${res.statusCode}');
  }
  ref.invalidate(ordonnancesProvider(officineId));
  // Le POST côté serveur génère aussi les prises pour les prescriptions.
  // On invalide TOUS les jours en cache pour que la timeline Aujourd'hui
  // (et les jours déjà chargés en navigation) prenne ces nouvelles
  // prises au prochain rebuild.
  ref.invalidate(prisesDayProvider);
  return res.data!;
}
