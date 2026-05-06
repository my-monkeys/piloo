import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/data/session_storage.dart';
import 'features/auth/presentation/session_provider.dart';

void main() {
  // Storage natif (Keychain iOS / EncryptedSharedPreferences Android).
  // En tests on override avec `InMemorySecureStorage` — voir
  // test/features/auth/session_provider_test.dart.
  final storage = SessionStorage(FlutterSecureStorageImpl());

  runApp(
    ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage)],
      child: const PilooApp(),
    ),
  );
}
