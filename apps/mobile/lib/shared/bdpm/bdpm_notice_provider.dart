// Provider Riverpod pour la notice ANSM scrapée (#non-ticket, suite
// remontée user sur la fiche médicament).
//
// Lazy : on n'appelle l'API que quand l'utilisateur ouvre la fiche.
// Côté serveur le résultat est caché 7 jours (cache HTTP edge Vercel),
// donc même charge réseau légère.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart';

import 'package:piloo/shared/api/api_client_provider.dart';
import 'package:piloo/shared/db/db_provider.dart';
import 'package:piloo/shared/db/local_db.dart';
import 'package:piloo/shared/bdpm/bdpm_notice_local_repo.dart';

class NoticeSection {
  const NoticeSection({
    required this.number,
    required this.title,
    required this.text,
  });
  final String number;
  final String title;
  final String text;
}

class BdpmNotice {
  const BdpmNotice({
    required this.cis,
    required this.sourceUrl,
    required this.sections,
  });
  final String cis;
  final String sourceUrl;
  final List<NoticeSection> sections;

  bool get isEmpty => sections.isEmpty;
}

/// Provider local-first. Stratégie :
///   1. Cache local Drift (instant, offline). Si présent ET pas stale
///      (< 7j), on retourne et on s'arrête.
///   2. Cache local stale ou absent → fetch API. On upsert le local
///      avant de retourner.
///   3. Si fetch API échoue ET on a un local stale → retourne le stale
///      plutôt que de planter.
final bdpmNoticeProvider =
    FutureProvider.family<BdpmNotice, String>((ref, cis) async {
  final db = ref.read(localDatabaseProvider);
  final client = ref.read(pilooApiClientProvider).getBdpmApi();
  return fetchNoticeLocalFirst(db: db, client: client, cis: cis);
});

class _ApiNotice {
  const _ApiNotice(this.notice, this.scrapedAt);
  final BdpmNotice notice;
  final DateTime scrapedAt;
}

/// Logique partagée entre le provider Riverpod et `prefetchNoticeIntoLocal`.
/// Exposée pour permettre l'injection des deps (db + client) sans passer
/// par un Ref — utile depuis un WidgetRef (qui n'est pas un Ref).
Future<BdpmNotice> fetchNoticeLocalFirst({
  required LocalDatabase db,
  required BdpmApi client,
  required String cis,
}) async {
  final repo = BdpmNoticeLocalRepo(db);
  final local = await repo.get(cis);
  final stale = await repo.isStale(cis);

  if (local != null && !stale) return local;

  try {
    final fresh = await _fetchFromApi(client, cis);
    await repo.upsert(fresh.notice, scrapedAt: fresh.scrapedAt);
    return fresh.notice;
  } catch (_) {
    if (local != null) return local;
    rethrow;
  }
}

Future<_ApiNotice> _fetchFromApi(BdpmApi client, String cis) async {
  final res = await client.v1BdpmCisNoticeGet(cis: cis);
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('GET /v1/bdpm/$cis/notice : statut ${res.statusCode}');
  }
  final body = res.data!;
  return _ApiNotice(
    BdpmNotice(
      cis: body.cis,
      sourceUrl: body.sourceUrl,
      sections: body.sections
          .map((s) => NoticeSection(
                number: s.number,
                title: s.title,
                text: s.text,
              ))
          .toList(growable: false),
    ),
    body.scrapedAt.toUtc(),
  );
}

/// Pré-télécharge une notice dans le cache local. Appelé en
/// fire-and-forget après l'ajout d'une boîte pour que l'ouverture de la
/// fiche soit instantanée. Erreurs silencieuses : on ne veut pas
/// bloquer le flow d'ajout si l'API ANSM tousse.
Future<void> prefetchNoticeIntoLocal(WidgetRef ref, String cis) async {
  try {
    final db = ref.read(localDatabaseProvider);
    final client = ref.read(pilooApiClientProvider).getBdpmApi();
    final repo = BdpmNoticeLocalRepo(db);
    final fresh = await _fetchFromApi(client, cis);
    await repo.upsert(fresh.notice, scrapedAt: fresh.scrapedAt);
  } catch (_) {
    // intentionnellement silencieux
  }
}
