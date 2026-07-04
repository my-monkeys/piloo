// Déclaration isolée du `routerProvider` (#361).
//
// Extrait de `router.dart` pour que des couches non-UI (ex. le client API
// dans shared/api) puissent pousser une route sans importer tout le graphe
// des écrans (et ses dépendances lourdes type phosphor_flutter). `router.dart`
// le ré-exporte, donc les imports existants restent inchangés.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Provider du router courant — override dans `app.dart` après
/// l'instanciation `buildRouter()`. Permet à n'importe quel widget
/// (y compris hors du Navigator, type overlays au niveau MaterialApp
/// .builder) de pousser une route via `ref.read(routerProvider)
/// .goNamed(...)`.
final routerProvider = Provider<GoRouter>((ref) {
  throw UnimplementedError(
    'routerProvider must be overridden in app.dart after buildRouter().',
  );
});
