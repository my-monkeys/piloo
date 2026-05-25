// Flag global "mode démo" (#351).
//
// Quand `true`, les providers métier (boitesProvider, prisesDayProvider,
// rappelsProvider, ordonnancesProvider, partagesProvider) retournent
// des fixtures Dart hardcodées au lieu de hitter l'API. Sert au tour
// guidé post-signup pour montrer l'app peuplée sans polluer la prod.
//
// Persisté via SecureStorage : reste actif tant que l'utilisateur n'a
// pas terminé / sauté le tour.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:piloo/core/storage/secure_storage.dart';

const _kDemoModeKey = 'piloo.demo_mode';

/// Override à la racine (main.dart / tests).
final secureStorageProvider = Provider<SecureStorage>((ref) {
  throw UnimplementedError(
    'secureStorageProvider must be overridden in main.dart with a real '
    'SecureStorage implementation (and in tests with InMemorySecureStorage).',
  );
});

class DemoModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final raw = await ref.read(secureStorageProvider).read(_kDemoModeKey);
    // DEBUG temp Phase 1 : forcer true pour valider les fixtures en sim.
    // À retirer en Phase 3 quand le toggle UI sera en place.
    return raw == 'true' || true;
  }

  Future<void> enable() async {
    await ref.read(secureStorageProvider).write(_kDemoModeKey, 'true');
    state = const AsyncData(true);
  }

  Future<void> disable() async {
    await ref.read(secureStorageProvider).write(_kDemoModeKey, 'false');
    state = const AsyncData(false);
  }
}

final demoModeProvider = AsyncNotifierProvider<DemoModeNotifier, bool>(
  DemoModeNotifier.new,
);

/// Lecture synchrone pour les wrappers de providers. Retourne false
/// tant que le flag n'est pas chargé (état AsyncLoading initial),
/// donc l'API tourne normalement par défaut.
bool isDemoMode(Ref ref) {
  return ref.watch(demoModeProvider).valueOrNull ?? false;
}
