// Tests BdpmSync (#78 #79).
//
// On utilise un fake BdpmApi qui simule version + download sans
// toucher au réseau. Pour le download, on écrit un vrai fichier
// SQLite valide sur disque (temp dir) afin que `BdpmDb.open` puisse
// le relire correctement après "download".
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piloo/shared/bdpm/bdpm_api.dart';
import 'package:piloo/shared/bdpm/bdpm_sync.dart';
import 'package:sqlite3/sqlite3.dart';

class _FakeBdpmApi extends BdpmApi {
  _FakeBdpmApi({
    required this.versionResponse,
    this.versionError,
    this.downloadError,
  }) : super(Dio());

  BdpmVersionResponse versionResponse;
  Object? versionError;
  Object? downloadError;
  int downloadCount = 0;

  @override
  Future<BdpmVersionResponse> getVersion() async {
    if (versionError != null) {
      throw versionError!;
    }
    return versionResponse;
  }

  @override
  Future<void> downloadSqlite(
    String url,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    downloadCount++;
    if (downloadError != null) {
      throw downloadError!;
    }
    // Écrit un VRAI fichier SQLite avec la version dans bdpm_metadata.
    // BdpmSync va le rouvrir via BdpmDb pour vérifier la version locale.
    final version = versionResponse.version!;
    final db = sqlite3.open(localPath);
    try {
      db.execute('''
        CREATE TABLE bdpm_metadata (key TEXT PRIMARY KEY, value TEXT) WITHOUT ROWID;
        CREATE TABLE medicaments (cis TEXT PRIMARY KEY, cip13 TEXT, denomination TEXT NOT NULL, version_bdpm TEXT NOT NULL) WITHOUT ROWID;
      ''');
      db.execute(
        "INSERT INTO bdpm_metadata VALUES ('version', '$version'), ('total_cis', '0')",
      );
    } finally {
      db.dispose();
    }
    onProgress?.call(1024, 1024);
  }
}

late Directory tmpDir;

void main() {
  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('piloo-bdpm-test-');
  });
  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  String localPath() => '${tmpDir.path}/bdpm.sqlite';
  String urlBuilder(String v) => 'https://example.test/bdpm-$v.sqlite';

  test('initial download : pas de fichier local → outcome.initialDownload', () async {
    final api = _FakeBdpmApi(
      versionResponse:
          const BdpmVersionResponse(version: '2026-05-01', totalCis: 1234),
    );
    final sync = BdpmSync(
      api: api,
      localSqlitePath: localPath(),
      buildDownloadUrl: urlBuilder,
    );
    final result = await sync.ensureUpToDate();
    expect(result.outcome, BdpmSyncOutcome.initialDownload);
    expect(result.localVersion, '2026-05-01');
    expect(api.downloadCount, 1);
    expect(File(localPath()).existsSync(), isTrue);
  });

  test('upToDate : version locale = serveur → no-op (pas de re-download)', () async {
    // Pré-écrit un fichier local avec la version 2026-05-01.
    final apiInit = _FakeBdpmApi(
      versionResponse:
          const BdpmVersionResponse(version: '2026-05-01', totalCis: 1234),
    );
    await BdpmSync(
      api: apiInit,
      localSqlitePath: localPath(),
      buildDownloadUrl: urlBuilder,
    ).ensureUpToDate();
    expect(apiInit.downloadCount, 1);

    // 2e pass avec le même serveur → aucun download.
    final api = _FakeBdpmApi(
      versionResponse:
          const BdpmVersionResponse(version: '2026-05-01', totalCis: 1234),
    );
    final result = await BdpmSync(
      api: api,
      localSqlitePath: localPath(),
      buildDownloadUrl: urlBuilder,
    ).ensureUpToDate();
    expect(result.outcome, BdpmSyncOutcome.upToDate);
    expect(api.downloadCount, 0);
  });

  test('updated : version serveur > version locale → re-download', () async {
    // Local 2026-05-01.
    final apiInit = _FakeBdpmApi(
      versionResponse:
          const BdpmVersionResponse(version: '2026-05-01', totalCis: 1234),
    );
    await BdpmSync(
      api: apiInit,
      localSqlitePath: localPath(),
      buildDownloadUrl: urlBuilder,
    ).ensureUpToDate();

    // Serveur passe à 2026-06-01.
    final api = _FakeBdpmApi(
      versionResponse:
          const BdpmVersionResponse(version: '2026-06-01', totalCis: 1300),
    );
    final result = await BdpmSync(
      api: api,
      localSqlitePath: localPath(),
      buildDownloadUrl: urlBuilder,
    ).ensureUpToDate();
    expect(result.outcome, BdpmSyncOutcome.updated);
    expect(result.localVersion, '2026-06-01');
    expect(api.downloadCount, 1);
  });

  test('offline : getVersion lève → outcome.offline, fichier local préservé', () async {
    // Pré-écrit un fichier local valide.
    await BdpmSync(
      api: _FakeBdpmApi(
        versionResponse:
            const BdpmVersionResponse(version: '2026-05-01', totalCis: 1234),
      ),
      localSqlitePath: localPath(),
      buildDownloadUrl: urlBuilder,
    ).ensureUpToDate();

    // Maintenant le serveur est offline.
    final api = _FakeBdpmApi(
      versionResponse:
          const BdpmVersionResponse(version: '2026-06-01', totalCis: 1300),
      versionError: DioException(
        requestOptions: RequestOptions(path: '/api/v1/bdpm/version'),
        type: DioExceptionType.connectionError,
      ),
    );
    final result = await BdpmSync(
      api: api,
      localSqlitePath: localPath(),
      buildDownloadUrl: urlBuilder,
    ).ensureUpToDate();
    expect(result.outcome, BdpmSyncOutcome.offline);
    expect(result.localVersion, '2026-05-01');
    // Le fichier précédent est toujours là.
    expect(File(localPath()).existsSync(), isTrue);
  });

  test('serveur retourne version=null (pas encore importé) + pas de local → offline', () async {
    final api = _FakeBdpmApi(
      versionResponse: const BdpmVersionResponse(version: null, totalCis: 0),
    );
    final result = await BdpmSync(
      api: api,
      localSqlitePath: localPath(),
      buildDownloadUrl: urlBuilder,
    ).ensureUpToDate();
    expect(result.outcome, BdpmSyncOutcome.offline);
    expect(api.downloadCount, 0);
  });

  test('download error : fichier temp nettoyé, fichier local préservé', () async {
    // Pré-écrit un fichier local valide.
    await BdpmSync(
      api: _FakeBdpmApi(
        versionResponse:
            const BdpmVersionResponse(version: '2026-05-01', totalCis: 1234),
      ),
      localSqlitePath: localPath(),
      buildDownloadUrl: urlBuilder,
    ).ensureUpToDate();

    final api = _FakeBdpmApi(
      versionResponse:
          const BdpmVersionResponse(version: '2026-06-01', totalCis: 1300),
      downloadError: DioException(
        requestOptions: RequestOptions(path: '/bdpm/file.sqlite'),
        type: DioExceptionType.connectionTimeout,
      ),
    );
    final result = await BdpmSync(
      api: api,
      localSqlitePath: localPath(),
      buildDownloadUrl: urlBuilder,
    ).ensureUpToDate();
    expect(result.outcome, BdpmSyncOutcome.offline);
    // Le fichier .tmp ne doit PAS rester sur disque.
    expect(File('${localPath()}.tmp').existsSync(), isFalse);
    // Le fichier local 2026-05-01 est intact.
    expect(File(localPath()).existsSync(), isTrue);
    expect(result.localVersion, '2026-05-01');
  });
}
