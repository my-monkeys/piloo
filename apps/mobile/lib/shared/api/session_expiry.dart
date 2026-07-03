// Gestion centralisée des 401 (session expirée/rejetée) — #361.
//
// Le bearer token Better Auth expire (~7j). Avant ce module, un token
// périmé faisait échouer les appels /v1/* en 401, que les providers
// avalaient en silence (officine vide, aucun message). On détecte
// désormais le 401 et on force une reconnexion propre.
import 'package:dio/dio.dart';

/// Intercepteur Dio : signale chaque réponse (ou erreur) 401 via un
/// callback. Volontairement bête — la *décision* (déconnecter, rediriger)
/// vit dans [SessionExpiryHandler], ce qui garde l'intercepteur trivial à
/// tester et découplé de Riverpod/router.
class UnauthorizedInterceptor extends Interceptor {
  UnauthorizedInterceptor(this._onUnauthorized);

  final void Function() _onUnauthorized;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // Le Dio métier a `validateStatus: (s) => s < 500`, donc un 401 arrive
    // toujours ici comme réponse "valide" (jamais en onError). Les erreurs
    // réseau (offline, timeout) passent par onError et ne nous concernent
    // pas — offline-first, on ne déconnecte jamais faute de réseau.
    if (response.statusCode == 401) _onUnauthorized();
    handler.next(response);
  }
}

/// Décide quoi faire quand un 401 est détecté. Pur (aucune dépendance
/// Dio/Riverpod/router) → entièrement testable en isolation.
///
/// Garanties :
///  - déclenche [onExpired] **au plus une fois** par session (les 401
///    concurrents des appels parallèles ne provoquent qu'une redirection) ;
///  - ne fait rien en mode démo (les fixtures ne tapent pas l'API, un 401
///    résiduel ne doit pas éjecter l'utilisateur) ;
///  - ne fait rien si on n'était pas authentifié (évite une boucle avec
///    les 401 légitimes de l'écran de connexion).
///
/// Appeler [reset] à chaque nouvelle connexion ré-arme le handler.
class SessionExpiryHandler {
  SessionExpiryHandler({
    required this.isAuthenticated,
    required this.isDemo,
    required this.onExpired,
  });

  final bool Function() isAuthenticated;
  final bool Function() isDemo;
  final void Function() onExpired;

  bool _handled = false;

  void handleUnauthorized() {
    if (_handled) return;
    if (isDemo()) return;
    if (!isAuthenticated()) return;
    _handled = true;
    onExpired();
  }

  void reset() => _handled = false;
}
