// Orchestrateur de sync BDPM (#78 + #79).
//
// Stratégie simple pour le MVP :
//
//   1. Au cold start, vérifier la version locale (si fichier présent)
//      vs version serveur via GET /api/v1/bdpm/version.
//   2. Si pas de fichier local → download initial (#78).
//   3. Si version serveur > version locale → re-download complet (#79).
//      Le diff endpoint /bdpm/diff existe (#76) mais on évite l'apply
//      incrémental côté mobile pour le MVP : un fichier .sqlite < 5 Mo
//      gzippé n'est pas plus lourd qu'un diff de 200 lignes en JSON.
//   4. Si versions identiques → no-op.
//
// AC #79 "Update silencieux si Wi-Fi + chargeur" : le check des
// conditions réseau/batterie est délégué au caller (un widget Riverpod
// dans l'écran Plus #115 par exemple). Cette classe se contente
// d'exposer `ensureUpToDate(force: bool)` ; le caller décide quand
// l'invoquer.
import 'dart:io';

import 'package:dio/dio.dart';

import 'bdpm_api.dart';
import 'bdpm_db.dart';

enum BdpmSyncOutcome {
  /// Fichier local absent au démarrage → download initial effectué.
  initialDownload,

  /// Version serveur plus récente → re-téléchargement complet effectué.
  updated,

  /// Versions identiques, rien à faire.
  upToDate,

  /// Network error ou serveur down ; on garde le fichier local s'il
  /// existe (mode dégradé acceptable pour offline-first).
  offline,
}

class BdpmSyncResult {
  const BdpmSyncResult({
    required this.outcome,
    this.localVersion,
    this.serverVersion,
    this.error,
  });
  final BdpmSyncOutcome outcome;
  final String? localVersion;
  final String? serverVersion;
  final Object? error;
}

class BdpmSync {
  BdpmSync({
    required BdpmApi api,
    required String localSqlitePath,
    required String Function(String version) buildDownloadUrl,
  })  : _api = api,
        _localSqlitePath = localSqlitePath,
        _buildDownloadUrl = buildDownloadUrl;

  final BdpmApi _api;
  final String _localSqlitePath;
  final String Function(String version) _buildDownloadUrl;

  /// Synchronise la BDPM locale. Idempotent — peut être appelé à
  /// chaque cold start sans conséquence si tout est déjà à jour.
  Future<BdpmSyncResult> ensureUpToDate({
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final localVersion = _readLocalVersion();

    final BdpmVersionResponse serverInfo;
    try {
      serverInfo = await _api.getVersion();
    } on DioException catch (e) {
      return BdpmSyncResult(
        outcome: BdpmSyncOutcome.offline,
        localVersion: localVersion,
        error: e,
      );
    }

    final serverVersion = serverInfo.version;
    if (serverVersion == null) {
      // Serveur n'a pas encore importé de BDPM (#75 pas tourné).
      // Si on n'a rien en local non plus, on remonte offline pour que
      // l'app affiche le fallback "aucun médicament reconnu".
      return BdpmSyncResult(
        outcome: localVersion == null
            ? BdpmSyncOutcome.offline
            : BdpmSyncOutcome.upToDate,
        localVersion: localVersion,
      );
    }

    if (localVersion == serverVersion) {
      return BdpmSyncResult(
        outcome: BdpmSyncOutcome.upToDate,
        localVersion: localVersion,
        serverVersion: serverVersion,
      );
    }

    // Download (initial OU update) — dans les deux cas on remplace le
    // fichier local par la version serveur. On télécharge dans un fichier
    // temporaire pour ne pas corrompre l'existant en cas d'erreur.
    final tmpPath = '$_localSqlitePath.tmp';
    try {
      await _api.downloadSqlite(
        _buildDownloadUrl(serverVersion),
        tmpPath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      // Atomique sur tous les FS POSIX-like et sur Android.
      await File(tmpPath).rename(_localSqlitePath);
    } catch (e) {
      // Cleanup du temp si présent.
      final tmp = File(tmpPath);
      if (tmp.existsSync()) {
        try {
          await tmp.delete();
        } catch (_) {
          // Best-effort, le temp sera ramassé au prochain run.
        }
      }
      return BdpmSyncResult(
        outcome: BdpmSyncOutcome.offline,
        localVersion: localVersion,
        serverVersion: serverVersion,
        error: e,
      );
    }

    return BdpmSyncResult(
      outcome: localVersion == null
          ? BdpmSyncOutcome.initialDownload
          : BdpmSyncOutcome.updated,
      localVersion: serverVersion,
      serverVersion: serverVersion,
    );
  }

  /// Lit la version du fichier local sans garder la connexion ouverte.
  /// Retourne null si le fichier est absent ou non lisible.
  String? _readLocalVersion() {
    final file = File(_localSqlitePath);
    if (!file.existsSync()) return null;
    try {
      final db = BdpmDb.open(_localSqlitePath);
      try {
        return db.version;
      } finally {
        db.close();
      }
    } catch (_) {
      return null;
    }
  }
}
