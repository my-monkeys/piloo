// Client HTTP BDPM (#78 #79).
//
// Endpoints publics — pas d'auth requise (cf. #76 côté serveur).
//
//   GET /api/v1/bdpm/version
//   GET /api/v1/bdpm/diff?from=YYYY-MM-DD
//   GET <download_url>           ← fichier .sqlite, download via Dio
import 'package:dio/dio.dart';

class BdpmVersionResponse {
  const BdpmVersionResponse({required this.version, required this.totalCis});
  final String? version;
  final int totalCis;

  factory BdpmVersionResponse.fromJson(Map<String, dynamic> json) =>
      BdpmVersionResponse(
        version: json['version'] as String?,
        totalCis: (json['total_cis'] as num?)?.toInt() ?? 0,
      );
}

class BdpmApi {
  BdpmApi(this._dio);

  final Dio _dio;

  Future<BdpmVersionResponse> getVersion() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/v1/bdpm/version');
    return BdpmVersionResponse.fromJson(res.data!);
  }

  /// Télécharge le fichier `.sqlite` BDPM vers `localPath`. Le callback
  /// `onProgress` reçoit `(received, total)` à chaque chunk pour
  /// permettre l'affichage d'une progress bar (AC #78). Si l'API ne
  /// renvoie pas de Content-Length, `total` est -1.
  ///
  /// Reprise si interrompu : Dio gère via `Range` headers, mais on
  /// délègue au caller le restart logic (sufficient pour MVP — un
  /// download interrompu = on retente à 0 au prochain lancement).
  Future<void> downloadSqlite(
    String url,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await _dio.download(
      url,
      localPath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
      // Le serveur peut renvoyer un fichier > 60 Mo avec gzip, on lève
      // la limite par défaut de Dio (qui buffer en mémoire si pas
      // configuré pour stream sur disque — `download` stream OK).
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
  }
}
