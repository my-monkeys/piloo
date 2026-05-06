// Provider Riverpod de la base locale Drift (#47).
//
// Override obligatoire au boot dans `main.dart` (pour ouvrir une vraie
// `LocalDatabase()`) et dans les tests (pour ouvrir un
// `LocalDatabase.forTesting(NativeDatabase.memory())`). On lève une
// `UnimplementedError` par défaut pour éviter qu'un appel oublié ouvre
// silencieusement une DB vide.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_db.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  throw UnimplementedError(
    'localDatabaseProvider must be overridden in main.dart with `LocalDatabase()` '
    '— and in tests with `LocalDatabase.forTesting(NativeDatabase.memory())`.',
  );
});
