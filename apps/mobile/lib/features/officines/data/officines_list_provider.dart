// Provider Riverpod listant TOUTES les officines accessibles à l'user.
//
// Distinction avec `activeOfficineProvider` : ici on a la liste complète
// (perso, partagées, pro). Utilisé par l'écran "Mes officines" (#72) et
// le compteur du Plus screen.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart';

import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/shared/api/api_client_provider.dart';

final officinesListProvider = FutureProvider<List<Officine>>((ref) async {
  // #359 — re-fetch au login (sinon la liste reste vide jusqu'au redémarrage).
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const <Officine>[];
  final api = ref.read(pilooApiClientProvider).getOfficinesApi();
  final res = await api.v1OfficinesGet();
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('GET /v1/officines : statut ${res.statusCode}');
  }
  return res.data!.items.toList();
});
