// Service qui pilote les SDK natifs Apple (#64) et Google (#65) pour
// obtenir un id_token, puis le forwarde à Better Auth via [AuthApi].
//
// Côté Better Auth, /api/auth/sign-in/social accepte `idToken: { token, nonce }`
// et vérifie la signature + l'audience contre :
//   - Apple : `appBundleIdentifier` (fr.mymonkey.piloo)
//   - Google : le Web client ID (variable `GOOGLE_CLIENT_ID` côté serveur)
//
// Pour Google, c'est `serverClientId` côté natif (= Web client ID) qui
// détermine le `aud` du token retourné — surtout PAS le clientId iOS/Android.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'auth_api.dart';
import 'session.dart';

/// Web client ID Google — utilisé comme `serverClientId` côté natif iOS/Android
/// pour que Google émette un id_token dont `aud` corresponde au backend.
///
/// Surchargeable via dart-define :
///   --dart-define=GOOGLE_WEB_CLIENT_ID=325543119788-bc1u1cij7mldu37vjs5mcuitulr6q1tq.apps.googleusercontent.com
const String _defaultGoogleWebClientId =
    '325543119788-bc1u1cij7mldu37vjs5mcuitulr6q1tq.apps.googleusercontent.com';

String _googleWebClientId() {
  const fromEnv = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  return fromEnv.isNotEmpty ? fromEnv : _defaultGoogleWebClientId;
}

/// Erreurs propres au flow social. `cancelled` n'est pas une vraie erreur,
/// juste un retour utilisateur — l'UI ne doit pas afficher de toast d'erreur.
class SocialSignInCancelled implements Exception {
  const SocialSignInCancelled();
}

class SocialSignInFailure implements Exception {
  SocialSignInFailure(this.message);
  final String message;

  @override
  String toString() => 'SocialSignInFailure: $message';
}

class SocialSignInService {
  SocialSignInService(this._authApi, {GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final AuthApi _authApi;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;

  /// Flow Apple Sign-In natif iOS (HIG-compliant via le bouton officiel).
  /// Sur Android le package fonctionne via flow web — non couvert au MVP.
  Future<Session> signInWithApple() async {
    if (!await SignInWithApple.isAvailable()) {
      throw SocialSignInFailure(
        "Sign in with Apple n'est pas disponible sur cet appareil.",
      );
    }
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256(rawNonce);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // Apple signe l'id_token avec ce nonce hashé — Better Auth attend
        // le nonce *brut* côté serveur pour vérifier l'égalité après re-hash.
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw SocialSignInFailure('Apple : id_token manquant dans la réponse.');
      }
      return await _authApi.signInSocial(
        provider: 'apple',
        idToken: idToken,
        nonce: rawNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialSignInCancelled();
      }
      throw SocialSignInFailure('Apple : ${e.message}');
    } on PlatformException catch (e) {
      throw SocialSignInFailure(
        'Apple : ${e.message ?? e.code} (plateforme non supportée ?)',
      );
    }
  }

  /// Flow Google Sign-In natif (Credential Manager sur Android 7.x+,
  /// flow Apple-style sheet sur iOS).
  Future<Session> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    try {
      final account = await _googleSignIn.authenticate();
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw SocialSignInFailure(
          'Google : id_token manquant (`serverClientId` mal configuré ?)',
        );
      }
      return await _authApi.signInSocial(
        provider: 'google',
        idToken: idToken,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialSignInCancelled();
      }
      throw SocialSignInFailure('Google : ${e.description ?? e.code.name}');
    } on PlatformException catch (e) {
      throw SocialSignInFailure(
        'Google : ${e.message ?? e.code}',
      );
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(serverClientId: _googleWebClientId());
    _googleInitialized = true;
  }

  static String _generateNonce([int length = 32]) {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final rng = Random.secure();
    return List.generate(length, (_) => charset[rng.nextInt(charset.length)]).join();
  }

  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
