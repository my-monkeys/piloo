// Persistance du `Session` mobile dans `SecureStorage` (#46).
import 'package:piloo/core/storage/secure_storage.dart';
import 'package:piloo/features/auth/data/session.dart';

class SessionStorage {
  SessionStorage(this._storage);

  static const _key = 'piloo.session';

  final SecureStorage _storage;

  Future<Session?> read() async {
    final raw = await _storage.read(_key);
    if (raw == null) return null;
    try {
      return Session.deserialize(raw);
    } catch (_) {
      // Format inattendu → on supprime pour éviter de boucler à chaque
      // démarrage. Le user devra se reconnecter, scénario rare.
      await _storage.delete(_key);
      return null;
    }
  }

  Future<void> write(Session session) =>
      _storage.write(_key, session.serialize());

  Future<void> clear() => _storage.delete(_key);
}
