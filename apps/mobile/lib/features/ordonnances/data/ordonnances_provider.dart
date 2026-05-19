// Provider Riverpod liste des ordonnances pour l'officine active.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

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
