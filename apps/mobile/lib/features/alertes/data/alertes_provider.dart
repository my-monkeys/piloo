// Provider Riverpod des alertes de l'utilisateur courant.
//
// GET /v1/alertes retourne toutes les alertes des officines auxquelles
// l'user a accès, owner ou non. Le tri par created_at desc est fait
// côté serveur.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/shared/api/api_client_provider.dart';

final alertesProvider = FutureProvider<List<api.Alerte>>((ref) async {
  final client = ref.read(pilooApiClientProvider).getAlertesApi();
  final res = await client.v1AlertesGet();
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('GET /v1/alertes : statut ${res.statusCode}');
  }
  return res.data!.items.toList();
});

Future<void> markAlerteRead(WidgetRef ref, String alerteId) async {
  final client = ref.read(pilooApiClientProvider).getAlertesApi();
  final res = await client.v1AlertesIdReadPost(id: alerteId);
  if (res.statusCode != 204 && res.statusCode != 200) {
    throw Exception('POST /v1/alertes/{id}/read : statut ${res.statusCode}');
  }
  ref.invalidate(alertesProvider);
}
