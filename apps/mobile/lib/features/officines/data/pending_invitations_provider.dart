// Provider Riverpod des invitations en attente adressées à l'user (#129).
//
// Source : GET /v1/me/invitations. Le retour `PendingInvitation[]` est
// dérivé de l'email de l'utilisateur courant (filtre côté backend).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart';

import 'package:piloo/shared/api/api_client_provider.dart';

final pendingInvitationsProvider = FutureProvider<List<PendingInvitation>>((ref) async {
  final api = ref.read(pilooApiClientProvider).getInvitationsApi();
  final res = await api.v1MeInvitationsGet();
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('GET /v1/me/invitations : statut ${res.statusCode}');
  }
  return res.data!.items.toList();
});

/// POST /v1/invitations/{token}/accept. Le caller doit invalidate les
/// providers concernés (pending + officinesList).
Future<void> acceptInvitation(WidgetRef ref, String token) async {
  final api = ref.read(pilooApiClientProvider).getInvitationsApi();
  final res = await api.v1InvitationsTokenAcceptPost(token: token);
  if (res.statusCode != 200) {
    throw Exception('POST /v1/invitations/{token}/accept : statut ${res.statusCode}');
  }
}
