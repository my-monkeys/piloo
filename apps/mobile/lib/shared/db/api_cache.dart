// Cache de réponses API en SQLite (table `api_cache`, créée hors Drift
// codegen). Pattern stale-while-revalidate : on sert le cache en premier
// pour un affichage instantané, puis on refresh depuis le réseau.
import 'package:drift/drift.dart';

import 'local_db.dart';

class ApiCacheRepo {
  ApiCacheRepo(this._db);

  final LocalDatabase _db;

  Future<String?> get(String key) async {
    final rows = await _db.customSelect(
      'SELECT response_json FROM api_cache WHERE key = ?',
      variables: [Variable.withString(key)],
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.data['response_json'] as String;
  }

  Future<void> put(String key, String json) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.customStatement(
      'INSERT OR REPLACE INTO api_cache (key, response_json, fetched_at) '
      'VALUES (?, ?, ?)',
      [key, json, now],
    );
  }

  Future<void> invalidate(String key) async {
    await _db.customStatement(
      'DELETE FROM api_cache WHERE key = ?',
      [key],
    );
  }

  Future<void> invalidatePrefix(String prefix) async {
    await _db.customStatement(
      "DELETE FROM api_cache WHERE key LIKE ? || '%'",
      [prefix],
    );
  }
}
