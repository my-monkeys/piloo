// Client HTTP minimal vers les endpoints Better Auth (#60).
//
// On ne passe pas par le client OpenAPI généré : Better Auth n'expose pas
// son contrat dans `packages/api-contract` (les routes sont gérées côté
// catch-all `[...all]`, hors de notre OpenAPI). Le contrat est néanmoins
// stable (ADR 0004) — REST documenté.
//
// Format de retour signup :
//   - header `set-auth-token` : bearer mobile (plugin `bearer()` côté
//     server, ADR 0004 §"Conséquences").
//   - body : `{ user: { id, email, name, ... }, token: ... }`.
import 'package:dio/dio.dart';

import 'session.dart';

class AuthApiException implements Exception {
  AuthApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthApiException($code, $statusCode): $message';
}

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// POST /api/auth/sign-in/email — Better Auth.
  Future<Session> signInEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/sign-in/email',
        data: {'email': email, 'password': password},
        options: Options(validateStatus: (s) => s != null),
      );
      if (response.statusCode != 200) {
        throw _exceptionFromError(response.data, response.statusCode);
      }
      final body = response.data!;
      final user = body['user'] as Map<String, dynamic>;
      final token = response.headers.value('set-auth-token');
      if (token == null || token.isEmpty) {
        throw AuthApiException(
          'missing_bearer',
          'Réponse signin sans header set-auth-token (plugin bearer absent ?)',
        );
      }
      return Session(
        token: token,
        userId: user['id'] as String,
        email: user['email'] as String,
        name: (user['name'] as String?) ?? '',
      );
    } on DioException catch (e) {
      throw _exceptionFromDio(e);
    }
  }

  /// POST /api/auth/sign-in/social — Better Auth (flow id-token natif, #64/#65).
  ///
  /// Le client natif (sign_in_with_apple / google_sign_in) récupère l'id_token
  /// auprès du provider ; on le forwarde au backend qui le vérifie (signature,
  /// audience = clientId/appBundleIdentifier) et crée ou retrouve l'user.
  /// Le header `set-auth-token` (plugin bearer) est posé comme pour le signin
  /// email.
  Future<Session> signInSocial({
    required String provider,
    required String idToken,
    String? nonce,
    String? accessToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/sign-in/social',
        data: {
          'provider': provider,
          'idToken': {
            'token': idToken,
            if (nonce != null && nonce.isNotEmpty) 'nonce': nonce,
            if (accessToken != null && accessToken.isNotEmpty) 'accessToken': accessToken,
          },
          // Pas de redirection : on est en flow natif, callbackURL ignoré
          // par Better Auth quand l'id_token est passé.
          'disableRedirect': true,
        },
        options: Options(validateStatus: (s) => s != null),
      );
      if (response.statusCode != 200) {
        throw _exceptionFromError(response.data, response.statusCode);
      }
      final body = response.data!;
      final user = body['user'] as Map<String, dynamic>;
      final token = response.headers.value('set-auth-token');
      if (token == null || token.isEmpty) {
        throw AuthApiException(
          'missing_bearer',
          'Réponse sign-in/social sans header set-auth-token (plugin bearer absent ?)',
        );
      }
      return Session(
        token: token,
        userId: user['id'] as String,
        email: user['email'] as String,
        name: (user['name'] as String?) ?? '',
      );
    } on DioException catch (e) {
      throw _exceptionFromDio(e);
    }
  }

  Future<Session> signUpEmail({
    required String email,
    required String password,
    required String name,
    required String nom,
    required String prenom,
    required String typeCompte,
    String? telephone,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/sign-up/email',
        data: {
          'email': email,
          'password': password,
          'name': name,
          'nom': nom,
          'prenom': prenom,
          'typeCompte': typeCompte,
          if (telephone != null && telephone.isNotEmpty) 'telephone': telephone,
        },
        options: Options(
          // Better Auth renvoie 4xx avec un body JSON utile en cas d'erreur ;
          // on le laisse passer pour pouvoir extraire le code/message.
          validateStatus: (s) => s != null,
        ),
      );
      if (response.statusCode != 200) {
        throw _exceptionFromError(response.data, response.statusCode);
      }
      final body = response.data!;
      final user = body['user'] as Map<String, dynamic>;
      final token = response.headers.value('set-auth-token');
      if (token == null || token.isEmpty) {
        throw AuthApiException(
          'missing_bearer',
          "Réponse signup sans header set-auth-token (plugin bearer() absent ?)",
        );
      }
      return Session(
        token: token,
        userId: user['id'] as String,
        email: user['email'] as String,
        name: (user['name'] as String?) ?? '',
      );
    } on DioException catch (e) {
      throw _exceptionFromDio(e);
    }
  }

  AuthApiException _exceptionFromError(dynamic body, int? statusCode) {
    if (body is Map<String, dynamic>) {
      // Better Auth retourne soit { code, message } directement, soit
      // wrapping {error:{code,message}} (notre format docs/api-contract.md).
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        return AuthApiException(
          (error['code'] as String?) ?? 'unknown_error',
          (error['message'] as String?) ?? 'Erreur inconnue',
          statusCode: statusCode,
        );
      }
      return AuthApiException(
        (body['code'] as String?) ?? 'unknown_error',
        (body['message'] as String?) ?? 'Erreur inconnue',
        statusCode: statusCode,
      );
    }
    return AuthApiException(
      'unknown_error',
      'Réponse non interprétable',
      statusCode: statusCode,
    );
  }

  AuthApiException _exceptionFromDio(DioException e) {
    if (e.response != null) {
      return _exceptionFromError(e.response!.data, e.response!.statusCode);
    }
    return AuthApiException(
      'network_error',
      'Pas de connexion (${e.message ?? "erreur réseau"})',
    );
  }
}
