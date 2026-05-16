// Provider du compteur d'opérations sync en attente (#95).
//
// Stream Drift `watch()` : on lit le COUNT(*) sur `pending_operations`
// où `statut='pending'`. Le stream émet à chaque insert/update/delete
// → l'UI consommatrice se met à jour sans tick manuel.
//
// Pourquoi un compteur dédié plutôt que d'écouter la liste complète :
//  - On n'a pas besoin des lignes elles-mêmes, juste du nombre.
//  - Évite de re-render à chaque changement de payload/retry_count
//    qui ne change pas le compteur.
//  - Drift `watchSingleOrNull` sur un select COUNT est optimisé en
//    interne (un seul rebuild par delta).
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:piloo/shared/db/db_provider.dart';
import 'package:piloo/shared/db/local_db.dart';

final pendingCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return watchPendingCount(db);
});

/// Stream du nombre d'ops en statut `pending` (i.e. non encore envoyées
/// au serveur). Exposé séparément pour faciliter le test direct sans
/// monter un `ProviderContainer`.
Stream<int> watchPendingCount(LocalDatabase db) {
  final count = db.pendingOperations.id.count();
  final query = db.selectOnly(db.pendingOperations)
    ..addColumns([count])
    ..where(db.pendingOperations.statut.equals('pending'));
  return query.map((row) => row.read(count) ?? 0).watchSingle();
}
