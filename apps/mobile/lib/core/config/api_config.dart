// Configuration de l'URL de base de l'API Piloo (#60).
//
// Prod : `https://app.piloo.fr`. Override en dev via dart-define :
//   flutter run --dart-define=PILOO_API_BASE_URL=http://192.168.1.42:3000
//
// Valeurs par défaut :
//  - localhost:3000  → fonctionne sur simulateur iOS et tests Flutter
//  - 10.0.2.2:3000   → l'équivalent côté émulateur Android (NAT host)
abstract class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('PILOO_API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return 'http://localhost:3000';
  }
}
