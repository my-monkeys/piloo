// Tests sur le sessionProvider (#46).
// Couverture : load au boot (vide / persisté), signIn écrit en storage,
// signOut clear, override de sessionStorageProvider en mémoire.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/storage/secure_storage.dart';
import 'package:piloo/features/auth/data/session.dart';
import 'package:piloo/features/auth/data/session_storage.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';

ProviderContainer makeContainer({SessionStorage? storage}) {
  final c = ProviderContainer(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        storage ?? SessionStorage(InMemorySecureStorage()),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

const _alice = Session(
  token: 'tok-alice',
  userId: 'user-alice',
  email: 'alice@piloo.fr',
  name: 'Alice Doe',
);

void main() {
  group('sessionProvider', () {
    test('build() retourne null quand le storage est vide', () async {
      final container = makeContainer();

      final value = await container.read(sessionProvider.future);

      expect(value, isNull);
    });

    test('build() retourne la session déjà persistée', () async {
      final storage = SessionStorage(InMemorySecureStorage());
      await storage.write(_alice);

      final container = makeContainer(storage: storage);
      final value = await container.read(sessionProvider.future);

      expect(value, _alice);
    });

    test('signIn() persiste et expose la session', () async {
      final storage = SessionStorage(InMemorySecureStorage());
      final container = makeContainer(storage: storage);
      await container.read(sessionProvider.future);

      await container.read(sessionProvider.notifier).signIn(_alice);

      expect(container.read(sessionProvider).value, _alice);
      expect(await storage.read(), _alice);
    });

    test('signOut() clear le storage et l\'état', () async {
      final storage = SessionStorage(InMemorySecureStorage());
      await storage.write(_alice);
      final container = makeContainer(storage: storage);
      await container.read(sessionProvider.future);

      await container.read(sessionProvider.notifier).signOut();

      expect(container.read(sessionProvider).value, isNull);
      expect(await storage.read(), isNull);
    });
  });

  group('Session (de)serialize', () {
    test('round-trip JSON', () {
      final raw = _alice.serialize();
      final parsed = Session.deserialize(raw);
      expect(parsed, _alice);
    });
  });

  group('SessionStorage avec format invalide', () {
    test('read() supprime l\'entrée et retourne null', () async {
      final storageImpl = InMemorySecureStorage();
      await storageImpl.write('piloo.session', 'not-json{');
      final storage = SessionStorage(storageImpl);

      final result = await storage.read();

      expect(result, isNull);
      expect(await storageImpl.read('piloo.session'), isNull);
    });
  });
}
