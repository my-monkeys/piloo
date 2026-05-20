// Providers Riverpod pour la preview + acceptance d'invitations.
//
// GET /v1/invitations/{token} → InvitationPreview pour afficher
// "Sophie t'invite à rejoindre l'officine Maison · rôle Éditeur".
// POST /v1/invitations/{token}/accept → ajoute l'utilisateur courant
// à l'officine. Nécessite d'être authentifié (sinon 401).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/shared/api/api_client_provider.dart';

final invitationPreviewProvider =
    FutureProvider.family<api.InvitationPreview, String>((ref, token) async {
  final client = ref.read(pilooApiClientProvider).getInvitationsApi();
  final res = await client.v1InvitationsTokenGet(token: token);
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('GET /v1/invitations/$token : ${res.statusCode}');
  }
  return res.data!;
});

Future<api.AcceptInvitationResponse> acceptInvitation(
  WidgetRef ref,
  String token,
) async {
  final client = ref.read(pilooApiClientProvider).getInvitationsApi();
  final res = await client.v1InvitationsTokenAcceptPost(token: token);
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('POST /v1/invitations/$token/accept : ${res.statusCode}');
  }
  return res.data!;
}
