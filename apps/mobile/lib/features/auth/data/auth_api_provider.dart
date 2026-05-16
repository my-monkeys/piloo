// Riverpod providers pour Dio + AuthApi (#60).
//
// `dioProvider` doit être overridé en tests pour injecter un mock
// (cf. `flutter_riverpod` + `dio_mock_adapter`-like, ou une simple Dio
// custom). En prod : pointe sur `ApiConfig.baseUrl`.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:piloo/core/config/api_config.dart';

import 'auth_api.dart';
import 'social_sign_in_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  return dio;
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});

final socialSignInProvider = Provider<SocialSignInService>((ref) {
  return SocialSignInService(ref.watch(authApiProvider));
});
