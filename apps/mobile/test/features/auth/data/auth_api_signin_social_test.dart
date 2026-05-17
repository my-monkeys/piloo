// Tests AuthApi.signInSocial (#287, follow-up #286).
//
// Mock Dio via un HttpClientAdapter custom — pas de réseau. On vérifie :
//   - Status 200 + header set-auth-token → Session bien parsée.
//   - Status 4xx avec body Better Auth → AuthApiException(code, message).
//   - Header set-auth-token manquant → exception `missing_bearer`.
//   - Erreur réseau (DioException sans response) → exception `network_error`.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/auth/data/auth_api.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.onFetch);

  final ResponseBody Function(RequestOptions) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => onFetch(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(
  Map<String, dynamic> body, {
  int status = 200,
  Map<String, List<String>>? headers,
}) {
  final bytes = utf8.encode(jsonEncode(body));
  return ResponseBody.fromBytes(
    bytes,
    status,
    headers: {
      'content-type': ['application/json'],
      ...?headers,
    },
  );
}

Dio _dioWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('AuthApi.signInSocial', () {
    test('200 + set-auth-token → Session typée', () async {
      final captured = <RequestOptions>[];
      final api = AuthApi(_dioWith(_FakeAdapter((opts) {
        captured.add(opts);
        return _json(
          {
            'user': {'id': 'user-1', 'email': 'a@b.fr', 'name': 'Alice'},
          },
          headers: {
            'set-auth-token': ['the-bearer'],
          },
        );
      })));

      final session = await api.signInSocial(
        provider: 'apple',
        idToken: 'tok',
        nonce: 'n',
      );

      expect(session.token, 'the-bearer');
      expect(session.userId, 'user-1');
      expect(session.email, 'a@b.fr');
      expect(session.name, 'Alice');
      expect(captured.single.path, '/api/auth/sign-in/social');
      final reqBody = captured.single.data as Map<String, dynamic>;
      expect(reqBody['provider'], 'apple');
      expect((reqBody['idToken'] as Map)['token'], 'tok');
      expect((reqBody['idToken'] as Map)['nonce'], 'n');
      expect(reqBody['disableRedirect'], true);
    });

    test('omet nonce et accessToken quand non fournis', () async {
      final captured = <RequestOptions>[];
      final api = AuthApi(_dioWith(_FakeAdapter((opts) {
        captured.add(opts);
        return _json(
          {
            'user': {'id': 'u', 'email': 'e@f.fr', 'name': 'N'},
          },
          headers: {
            'set-auth-token': ['t'],
          },
        );
      })));

      await api.signInSocial(provider: 'google', idToken: 'tok');
      final reqBody = (captured.single.data as Map<String, dynamic>);
      final idToken = reqBody['idToken'] as Map<String, dynamic>;
      expect(idToken.containsKey('nonce'), false);
      expect(idToken.containsKey('accessToken'), false);
    });

    test('4xx avec body {code, message} → AuthApiException', () async {
      final api = AuthApi(_dioWith(_FakeAdapter((_) => _json(
            {'code': 'invalid_token', 'message': 'Apple id token invalide'},
            status: 401,
          ))));

      expect(
        () => api.signInSocial(provider: 'apple', idToken: 'bad'),
        throwsA(isA<AuthApiException>()
            .having((e) => e.code, 'code', 'invalid_token')
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('4xx avec body wrapping {error: {code, message}} → AuthApiException', () async {
      final api = AuthApi(_dioWith(_FakeAdapter((_) => _json(
            {
              'error': {'code': 'forbidden', 'message': 'Pas autorisé.'},
            },
            status: 403,
          ))));

      expect(
        () => api.signInSocial(provider: 'apple', idToken: 'bad'),
        throwsA(isA<AuthApiException>()
            .having((e) => e.code, 'code', 'forbidden')
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('200 sans header set-auth-token → exception missing_bearer', () async {
      final api = AuthApi(_dioWith(_FakeAdapter((_) => _json({
            'user': {'id': 'u', 'email': 'e@f.fr', 'name': 'N'},
          }))));

      expect(
        () => api.signInSocial(provider: 'apple', idToken: 'tok'),
        throwsA(isA<AuthApiException>()
            .having((e) => e.code, 'code', 'missing_bearer')),
      );
    });

    test('erreur réseau (pas de response) → exception network_error', () async {
      final api = AuthApi(_dioWith(_FakeAdapter((opts) {
        throw DioException(
          requestOptions: opts,
          type: DioExceptionType.connectionError,
          message: 'No internet',
        );
      })));

      expect(
        () => api.signInSocial(provider: 'apple', idToken: 'tok'),
        throwsA(isA<AuthApiException>()
            .having((e) => e.code, 'code', 'network_error')),
      );
    });
  });
}
