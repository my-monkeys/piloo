// Providers Riverpod pour la liste des membres d'une officine et
// les mutations rôle/révocation (#339).
//
// Endpoints :
//   GET    /v1/officines/{id}/partages           → PartagesList
//   PATCH  /v1/officines/{id}/partages/{userId}  → change rôle
//   DELETE /v1/officines/{id}/partages/{userId}  → revoke / leave
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/shared/api/api_client_provider.dart';

final partagesProvider =
    FutureProvider.family<api.PartagesList, String>((ref, officineId) async {
  final client = ref.read(pilooApiClientProvider).getPartagesApi();
  final res = await client.v1OfficinesOfficineIdPartagesGet(officineId: officineId);
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('GET /v1/officines/$officineId/partages : ${res.statusCode}');
  }
  return res.data!;
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
