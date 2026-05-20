// Provider Riverpod du worker BdpmSync (#78/#79 wire-up).
//
// La classe BdpmSync existait depuis longtemps mais n'était jamais
// instanciée. Ce provider la construit en pointant sur l'endpoint
// `/api/v1/bdpm/sqlite` (ajouté pour #78). Le caller (splash) appelle
// `ensureUpToDate()` au cold start, fire-and-forget, pour télécharger
// le SQLite en background sans bloquer l'UI.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:piloo/core/config/api_config.dart';
import 'bdpm_api.dart';
import 'bdpm_provider.dart';
import 'bdpm_sync.dart';

/// Dio dédié à BdpmApi — utilise des paths absolus `/api/v1/bdpm/...`
/// (cf. bdpm_api.dart), donc la baseUrl ne doit PAS contenir `/api`
/// pour éviter le double préfixe.
final _bdpmDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );
});

final bdpmSyncProvider = FutureProvider<BdpmSync>((ref) async {
  final api = BdpmApi(ref.read(_bdpmDioProvider));
  final localPath = await bdpmLocalPath();
  return BdpmSync(
    api: api,
    localSqlitePath: localPath,
    // Pas de `?version=` ici : le param sert au serveur à répondre 304
    // si on a déjà la bonne version. Or BdpmSync n'appelle download que
    // s'il a déjà décidé de re-télécharger (version locale absente ou
    // périmée vs serveur). Mettre `?version=serverVersion` ferait
    // toujours 304 → fichier jamais sauvegardé → 'Aucune base locale'
    // permanente. Bug observé 2026-05-19.
    buildDownloadUrl: (_) => '${ApiConfig.baseUrl}/api/v1/bdpm/sqlite',
  );
});
