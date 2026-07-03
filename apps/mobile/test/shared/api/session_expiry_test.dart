// Tests du traitement des 401 (session expirée/rejetée) — #361.
//
// Deux unités pures, sans HTTP ni router :
//  - UnauthorizedInterceptor : détecte un 401 (réponse OU erreur Dio) et
//    déclenche un callback.
//  - SessionExpiryHandler : décide s'il faut forcer la reconnexion
//    (dédoublonnage des 401 concurrents, exemption mode démo, garde
//    "on était authentifié").
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/shared/api/session_expiry.dart';

Response<dynamic> _response(int status) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/v1/officines'),
      statusCode: status,
    );

void main() {
  group('UnauthorizedInterceptor', () {
    test('onResponse 401 déclenche le callback', () {
      var fired = 0;
      final interceptor = UnauthorizedInterceptor(() => fired++);

      interceptor.onResponse(_response(401), ResponseInterceptorHandler());

      expect(fired, 1);
    });

    test('onResponse 200 ne déclenche rien', () {
      var fired = 0;
      final interceptor = UnauthorizedInterceptor(() => fired++);

      interceptor.onResponse(_response(200), ResponseInterceptorHandler());

      expect(fired, 0);
    });
  });

  group('SessionExpiryHandler', () {
    SessionExpiryHandler make({
      required bool authenticated,
      required bool demo,
      required void Function() onExpired,
    }) =>
        SessionExpiryHandler(
          isAuthenticated: () => authenticated,
          isDemo: () => demo,
          onExpired: onExpired,
        );

    test('authentifié + hors démo → onExpired une seule fois', () {
      var expired = 0;
      final handler =
          make(authenticated: true, demo: false, onExpired: () => expired++);

      handler.handleUnauthorized();
      handler.handleUnauthorized(); // 401 concurrent : ne re-déclenche pas

      expect(expired, 1);
    });

    test('mode démo → jamais de déconnexion forcée', () {
      var expired = 0;
      final handler =
          make(authenticated: true, demo: true, onExpired: () => expired++);

      handler.handleUnauthorized();

      expect(expired, 0);
    });

    test('non authentifié → pas de déconnexion (évite la boucle au login)',
        () {
      var expired = 0;
      final handler =
          make(authenticated: false, demo: false, onExpired: () => expired++);

      handler.handleUnauthorized();

      expect(expired, 0);
    });

    test('reset() ré-arme après une nouvelle connexion', () {
      var expired = 0;
      final handler =
          make(authenticated: true, demo: false, onExpired: () => expired++);

      handler.handleUnauthorized();
      handler.reset();
      handler.handleUnauthorized();

      expect(expired, 2);
    });
  });
}
