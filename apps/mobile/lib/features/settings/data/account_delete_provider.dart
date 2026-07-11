// Suppression de compte (RGPD / App Store Guideline 5.1.1(v)).
//
// L'app permet la création de compte, elle doit donc offrir la
// suppression. Le backend applique une suppression différée (7 jours,
// annulable via /v1/me/restore) puis anonymise — voir web `lib/me/delete.ts`.
// Ici on ne fait que déclencher la demande ; l'UI se charge de la
// confirmation et de la déconnexion.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:piloo/shared/api/api_client_provider.dart';

/// Déclenche la suppression du compte courant. Retourne la date
/// d'anonymisation planifiée (fin du délai de grâce). Lève en cas
/// d'échec réseau/serveur pour que l'UI affiche l'erreur.
Future<DateTime> requestAccountDeletion(WidgetRef ref) async {
  final client = ref.read(pilooApiClientProvider).getRgpdApi();
  final res = await client.v1MeDeletePost();
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('POST /v1/me/delete : statut ${res.statusCode}');
  }
  return res.data!.scheduledAnonymizationAt;
}
