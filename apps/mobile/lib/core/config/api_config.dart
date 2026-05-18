// Configuration de l'URL de base de l'API Piloo (#60).
//
// Par défaut on pointe sur la prod (https://piloo.vercel.app). Override
// en dev via dart-define :
//   flutter run --dart-define=PILOO_API_BASE_URL=http://localhost:3000
//
// Variantes utiles en dev :
//  - http://localhost:3000   → simulateur iOS qui partage le loopback hôte
//  - http://10.0.2.2:3000    → équivalent côté émulateur Android (NAT host)
//  - http://192.168.x.y:3000 → device physique sur le LAN
abstract class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('PILOO_API_BASE_URL');

  /// URL prod par défaut. Sans dart-define, builds release et debug
  /// s'attaquent à l'instance Vercel hébergée — c'est ce qu'on veut pour
  /// "je télécharge le build sur mon tel, ça marche".
  static const String _defaultBaseUrl = 'https://piloo.vercel.app';

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return _defaultBaseUrl;
  }
}
