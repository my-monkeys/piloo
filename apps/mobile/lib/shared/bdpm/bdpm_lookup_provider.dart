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
  // 1. Local d'abord (instant + offline).
  final dbAsync = ref.watch(bdpmDbProvider);
  final db = dbAsync.valueOrNull;
  final local = db?.findByCip13(cip13);

  // Local-only si TOUTES les colonnes enrichies (ai_summary, totalDoses,
  // doseUnit) sont là. Sinon fallback API pour récupérer l'enrichissement
  // manquant — typique des SQLite mobiles plus anciens qui n'ont pas
  // encore les colonnes #165 (ai_summary) ou #presentation-enrichment
  // (totalDoses/doseUnit/container) ajoutées côté serveur.
  final hasAi = local?.aiSummary != null && local!.aiSummary!.isNotEmpty;
  final hasPresentation = local?.totalDoses != null && local?.doseUnit != null;
  if (local != null && hasAi && hasPresentation) {
    return local;
  }

  // 2. Fallback / enrichissement via API.
  try {
    final client = ref.read(pilooApiClientProvider).getBdpmApi();
    final res = await client.v1BdpmSearchGet(q: cip13);
    final items = res.data?.items.toList() ?? const <api.BdpmMedicament>[];
    if (items.isEmpty) return local; // pas de fallback API, on garde local.
    final match = items.firstWhere(
      (m) => m.cip13 == cip13,
      orElse: () => items.first,
    );
    return _fromApi(match);
  } catch (_) {
    return local; // on a au moins le local si l'API rate.
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
    libellePresentation: m.libellePresentation,
    container: m.container,
    totalDoses: m.totalDoses,
    doseUnit: m.doseUnit,
    doseUnitPlural: m.doseUnitPlural,
  );
}
