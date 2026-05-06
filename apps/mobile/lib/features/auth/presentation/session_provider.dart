// Provider Riverpod de la session (#46).
//
// `sessionStorageProvider` doit être overridé au démarrage de l'app
// avec une `SessionStorage` réelle (cf. `lib/main.dart`). En tests, on
// override avec une `SessionStorage(InMemorySecureStorage())`.
//
// `sessionProvider` est un `AsyncNotifier` qui :
// - charge la session persistée au boot (`build` async)
// - expose `signIn(session)` / `signOut()` qui mettent à jour à la fois
//   l'état Riverpod et le storage
// - reste cohérent avec le pattern offline-first : pas d'appel réseau
//   ici, on lit/écrit local. La synchro avec /api/auth/get-session se
//   fera côté repository auth quand le réseau est dispo.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:piloo/features/auth/data/session.dart';
import 'package:piloo/features/auth/data/session_storage.dart';

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  throw UnimplementedError(
    'sessionStorageProvider must be overridden in main.dart with a real '
    'SessionStorage(SecureStorage()) — and in tests with an in-memory one.',
  );
});

class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    return ref.read(sessionStorageProvider).read();
  }

  Future<void> signIn(Session session) async {
    state = const AsyncLoading();
    final storage = ref.read(sessionStorageProvider);
    await storage.write(session);
    state = AsyncData(session);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final storage = ref.read(sessionStorageProvider);
    await storage.clear();
    state = const AsyncData(null);
  }
}

final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);
