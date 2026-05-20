// Provider Riverpod qui résout un CIP13 → nom/forme/dosage du médicament.
//
// Stratégie :
//   1. Essaye d'abord le SQLite BDPM **local** (`bdpmDbProvider`) — instant,
//      offline-first.
//   2. Si null OU pas de match, fallback API `/v1/bdpm/search?q=CIP` —
//      nécessite réseau mais marche dès le 1er lancement (pas besoin
//      d'avoir téléchargé le SQLite).
//   3. Si l'API échoue, on remonte null (l'UI affiche "non reconnu").
//
// Cette compromis débloque le scan immédiatement, en attendant que la
// chaîne de sync SQLite local soit câblée bout-en-bout (#78/#79).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/shared/api/api_client_provider.dart';
import 'bdpm_medicament.dart';
import 'bdpm_provider.dart';

final bdpmLookupProvider =
    FutureProvider.family<BdpmMedicament?, String>((ref, cip13) async {
  // 1. Local d'abord.
  final dbAsync = ref.watch(bdpmDbProvider);
  final db = dbAsync.valueOrNull;
  if (db != null) {
    final local = db.findByCip13(cip13);
    if (local != null) return local;
  }

  // 2. Fallback API.
  try {
    final client = ref.read(pilooApiClientProvider).getBdpmApi();
    final res = await client.v1BdpmSearchGet(q: cip13);
    final items = res.data?.items.toList() ?? const <api.BdpmMedicament>[];
    if (items.isEmpty) return null;
    final match = items.firstWhere(
      (m) => m.cip13 == cip13,
      orElse: () => items.first,
    );
    return _fromApi(match);
  } catch (_) {
    return null;
  }
});

BdpmMedicament _fromApi(api.BdpmMedicament m) {
  // BdpmDb expose un modèle Dart léger (cf. bdpm_medicament.dart). On le
  // construit depuis le modèle du client OpenAPI pour que le screen ne
  // distingue pas entre source locale et source API.
  return BdpmMedicament(
    cis: m.cis,
    cip13: m.cip13,
    cip7: m.cip7,
    denomination: m.denomination,
    forme: m.forme,
    dosage: m.dosage,
    voieAdministration: m.voieAdministration,
    titulaire: m.titulaire,
    statutAmm: m.statutAmm,
    tauxRemboursement: m.tauxRemboursement,
    aiSummary: m.aiSummary,
  );
}
