// Wrapper minimal autour de `flutter_secure_storage` pour la session
// Better Auth (#46). On encapsule pour pouvoir injecter une fake en
// tests (le plugin natif ne fonctionne pas dans flutter_test).
//
// Pourquoi pas SharedPreferences : on stocke le bearer token Better
// Auth (cf. ADR 0004 §"Conséquences"). Sur iOS → Keychain, sur Android
// → EncryptedSharedPreferences/Keystore.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStorageImpl implements SecureStorage {
  FlutterSecureStorageImpl({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemorySecureStorage implements SecureStorage {
  // Implémentation in-memory pour les tests : flutter_secure_storage
  // utilise un MethodChannel natif qui n'est pas disponible dans le
  // bundle test par défaut.
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }
}
