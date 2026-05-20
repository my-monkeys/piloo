// Providers Riverpod pour le sync offline (#18).
//
// Chaîne au boot (cf. main.dart) :
//   1. clientIdProvider : UUID stable par device (SharedPreferences).
//   2. connectivitySourceProvider : RealConnectivitySource autour de
//      connectivity_plus.
//   3. opsUploaderProvider : DioOpsUploader vers /api/v1/sync/push.
//   4. syncWorkerProvider : SyncWorker.start() — réagit aux transitions
//      offline→online en flushant pending_operations.
//
// Tous overridable en test.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:piloo/core/config/api_config.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/shared/db/db_provider.dart';
import 'package:piloo/shared/sync/connectivity_source.dart';
import 'package:piloo/shared/sync/dio_ops_uploader.dart';
import 'package:piloo/shared/sync/ops_uploader.dart';
import 'package:piloo/shared/sync/sync_worker.dart';

/// Identifiant stable du device — UUID v4 généré au premier accès et
/// persisté dans SharedPreferences. Sert au backend pour dédupliquer
/// les opérations rejouées (idempotence).
const _clientIdKey = 'piloo.sync.client_id';

final clientIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_clientIdKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final generated = _generateUuidV4();
  await prefs.setString(_clientIdKey, generated);
  return generated;
});

final connectivitySourceProvider = Provider<ConnectivitySource>((ref) {
  return RealConnectivitySource();
});

/// Dio dédié au sync — sépare du Dio principal pour pouvoir mettre des
/// timeouts plus longs (un flush peut envelopper jusqu'à 100 ops si on
/// batch un jour). Pour l'instant 1 op/POST, mais on prévoit la marge.
final _syncDioProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionProvider).value;
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
  if (session != null) {
    dio.options.headers['Authorization'] = 'Bearer ${session.token}';
  }
  return dio;
});

final opsUploaderProvider = FutureProvider<OpsUploader>((ref) async {
  final dio = ref.watch(_syncDioProvider);
  final clientId = await ref.watch(clientIdProvider.future);
  return DioOpsUploader(dio: dio, clientId: clientId);
});

/// SyncWorker démarré au boot. `keepAlive` pour que la subscription
/// connectivity_plus ne soit pas annulée si le widget tree se reconstruit.
final syncWorkerProvider = FutureProvider<SyncWorker>((ref) async {
  final db = ref.watch(localDatabaseProvider);
  final connectivity = ref.watch(connectivitySourceProvider);
  final uploader = await ref.watch(opsUploaderProvider.future);
  final worker = SyncWorker(
    db: db,
    connectivity: connectivity,
    uploader: uploader,
  );
  worker.start();
  ref.onDispose(worker.stop);
  return worker;
});

/// Helper minimal de génération d'UUID v4 sans dépendance externe.
/// Cf. RFC 4122 §4.4.
String _generateUuidV4() {
  final r = _Rand();
  final bytes = List<int>.generate(16, (_) => r.next() & 0xFF);
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
  String hex(int i) => i.toRadixString(16).padLeft(2, '0');
  final s = bytes.map(hex).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

class _Rand {
  // dart:math Random est suffisant pour un client_id (pas de besoin
  // cryptographique strict côté device).
  final _r = _SimpleRandom(DateTime.now().microsecondsSinceEpoch);
  int next() => _r.next();
}

class _SimpleRandom {
  _SimpleRandom(this._state);
  int _state;
  int next() {
    // xorshift64 — assez bon pour un identifiant non-cryptographique.
    var x = _state;
    x ^= x << 13;
    x &= 0xFFFFFFFFFFFFFFFF;
    x ^= x >> 7;
    x ^= x << 17;
    x &= 0xFFFFFFFFFFFFFFFF;
    _state = x;
    return x & 0xFFFFFFFF;
  }
}
