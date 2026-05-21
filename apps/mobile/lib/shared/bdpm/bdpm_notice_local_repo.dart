// Repo Drift pour le cache local des notices ANSM (#cache-local).
//
// Côté serveur, ces données viennent de bdpm_notices_cache (Postgres).
// Côté mobile, on les pré-télécharge à l'ajout d'une boîte pour rendre
// l'ouverture de la fiche instantanée + offline-friendly.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'package:piloo/shared/db/local_db.dart';
import 'package:piloo/shared/bdpm/bdpm_notice_provider.dart';

const Duration kNoticeStaleDuration = Duration(days: 7);

class BdpmNoticeLocalRepo {
  BdpmNoticeLocalRepo(this._db);
  final LocalDatabase _db;

  Future<BdpmNotice?> get(String cis) async {
    final row = await (_db.select(_db.bdpmNoticesLocal)
          ..where((t) => t.cis.equals(cis)))
        .getSingleOrNull();
    if (row == null) return null;
    return _rowToNotice(row);
  }

  Future<void> upsert(BdpmNotice notice, {required DateTime scrapedAt}) async {
    final sectionsJson = jsonEncode(
      notice.sections
          .map((s) => {'number': s.number, 'title': s.title, 'text': s.text})
          .toList(),
    );
    await _db.into(_db.bdpmNoticesLocal).insertOnConflictUpdate(
          BdpmNoticesLocalCompanion(
            cis: Value(notice.cis),
            sourceUrl: Value(notice.sourceUrl),
            sectionsJson: Value(sectionsJson),
            scrapedAt: Value(scrapedAt.toUtc().toIso8601String()),
            fetchedAt: Value(DateTime.now().toUtc().toIso8601String()),
          ),
        );
  }

  /// True si la notice est absente OU vieille de plus de 7 jours
  /// (côté serveur — on regarde `scraped_at`, pas la date du download).
  Future<bool> isStale(String cis) async {
    final row = await (_db.select(_db.bdpmNoticesLocal)
          ..where((t) => t.cis.equals(cis)))
        .getSingleOrNull();
    if (row == null) return true;
    final scrapedAt = DateTime.tryParse(row.scrapedAt);
    if (scrapedAt == null) return true;
    return DateTime.now().toUtc().difference(scrapedAt) > kNoticeStaleDuration;
  }
}

BdpmNotice _rowToNotice(BdpmNoticeLocalRow row) {
  final raw = jsonDecode(row.sectionsJson) as List<dynamic>;
  final sections = raw
      .map((e) {
        final m = e as Map<String, dynamic>;
        return NoticeSection(
          number: m['number'] as String,
          title: m['title'] as String,
          text: m['text'] as String,
        );
      })
      .toList(growable: false);
  return BdpmNotice(cis: row.cis, sourceUrl: row.sourceUrl, sections: sections);
}
