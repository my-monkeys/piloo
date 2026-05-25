// Providers Riverpod pour la liste des membres d'une officine et
// les mutations rôle/révocation (#339).
//
// Endpoints :
//   GET    /v1/officines/{id}/partages           → PartagesList
//   PATCH  /v1/officines/{id}/partages/{userId}  → change rôle
//   DELETE /v1/officines/{id}/partages/{userId}  → revoke / leave
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/features/onboarding/data/demo_fixtures.dart';
import 'package:piloo/features/onboarding/data/demo_mode_provider.dart';
import 'package:piloo/shared/api/api_client_provider.dart';

final partagesProvider =
    FutureProvider.family<api.PartagesList, String>((ref, officineId) async {
  // Mode démo (#351) : retourne un partages list solo (user fictif
  // owner) pour montrer l'écran Membres peuplé.
  if (isDemoMode(ref)) {
    return demoPartages();
  }
  final client = ref.read(pilooApiClientProvider).getPartagesApi();
  try {
    final res = await client.v1OfficinesOfficineIdPartagesGet(officineId: officineId);
    if (res.statusCode != 200 || res.data == null) {
      throw Exception('Réponse inattendue (${res.statusCode}).');
    }
    return res.data!;
  } on DioException catch (e) {
    // Désérialisation foirée (body HTML, pas l'array attendu) →
    // typiquement l'endpoint n'existe pas encore en prod. Message
    // user-friendly plutôt que le stack trace cryptique.
    final isDeserError = e.error?.toString().contains('Deserializing') ?? false;
    if (isDeserError) {
      throw Exception(
        "Le partage d'officine n'est pas encore disponible sur ce serveur. "
        "Réessaie dans quelques minutes.",
      );
    }
    final code = e.response?.statusCode;
    if (code == 403) {
      throw Exception("Tu n'as pas les droits sur cette officine.");
    }
    if (code == 404) {
      throw Exception('Officine introuvable.');
    }
    throw Exception('Réseau indisponible. Vérifie ta connexion.');
  }
});

Future<api.PartageMember> updateMemberRole(
  WidgetRef ref, {
  required String officineId,
  required String userId,
  required api.UpdatePartageRoleInputRoleEnum role,
}) async {
  final client = ref.read(pilooApiClientProvider).getPartagesApi();
  final input = (api.UpdatePartageRoleInputBuilder()..role = role).build();
  final res = await client.v1OfficinesOfficineIdPartagesUserIdPatch(
    officineId: officineId,
    userId: userId,
    updatePartageRoleInput: input,
  );
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('PATCH partages : ${res.statusCode}');
  }
  ref.invalidate(partagesProvider(officineId));
  return res.data!;
}

Future<void> revokeMember(
  WidgetRef ref, {
  required String officineId,
  required String userId,
}) async {
  final client = ref.read(pilooApiClientProvider).getPartagesApi();
  final res = await client.v1OfficinesOfficineIdPartagesUserIdDelete(
    officineId: officineId,
    userId: userId,
  );
  if (res.statusCode != 204 && res.statusCode != 200) {
    throw Exception('DELETE partages : ${res.statusCode}');
  }
  ref.invalidate(partagesProvider(officineId));
}
