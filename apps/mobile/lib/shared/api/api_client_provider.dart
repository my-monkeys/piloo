// Provider Riverpod du client OpenAPI Dart Piloo.
//
// Un seul Dio pour tous les appels /api/v1/*, avec :
//   - baseURL = `ApiConfig.baseUrl`
//   - bearer token tiré de la session courante (signé via Better Auth
//     plugin bearer) — ajouté automatiquement dans `Authorization`.
//
// On n'utilise pas `BearerAuthInterceptor` du client généré faute de
// `securitySchemes` déclaré dans openapi.yaml. Un simple interceptor
// custom suffit et reste sous notre contrôle.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart';

import 'package:piloo/core/config/api_config.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';

final pilooApiClientProvider = Provider<PilooApiClient>((ref) {
  // Le client OpenAPI généré déclare ses chemins en `/v1/...` ; on doit
  // donc préfixer la baseURL avec `/api` pour atteindre les routes
  // Next.js (`/api/v1/...`). Sans ça les calls partent en 404.
  final apiBase = '${ApiConfig.baseUrl}/api';
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
      // Ne pas throw sur statut HTTP — on lit `response.statusCode` côté
      // appelant pour distinguer 401 (re-login) vs 5xx (retry).
      validateStatus: (s) => s != null && s < 500,
    ),
  );
  // Bearer injecté à chaque requête depuis le SecureStorage. On lit
  // depuis le storage plutôt que d'écouter `sessionProvider` pour éviter
  // de coupler les providers et permettre des appels même avant que le
  // provider soit "ready" (au boot).
  dio.interceptors.add(_BearerFromSessionInterceptor(ref));
  return PilooApiClient(dio: dio, basePathOverride: apiBase);
});

class _BearerFromSessionInterceptor extends Interceptor {
  _BearerFromSessionInterceptor(this._ref);

  final Ref _ref;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Évite de re-déclencher la lecture du storage à chaque requête en
    // s'appuyant sur l'état Riverpod quand il est dispo. Fallback : on
    // lit depuis le SessionStorage qui est lui-même un cache mémoire +
    // SecureStorage natif.
    final cached = _ref.read(sessionProvider).valueOrNull;
    if (cached != null) {
      options.headers['Authorization'] = 'Bearer ${cached.token}';
      handler.next(options);
      return;
    }
    final storage = _ref.read(sessionStorageProvider);
    final session = await storage.read();
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.token}';
    }
    handler.next(options);
  }
}
