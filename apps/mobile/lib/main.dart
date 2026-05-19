import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/data/session_storage.dart';
import 'features/auth/presentation/session_provider.dart';
import 'shared/db/db_provider.dart';
import 'shared/db/local_db.dart';
import 'shared/notifications/notifications_service.dart';

Future<void> main() async {
  // setSurfaceSize() côté tests sinon binding null — l'init du plugin
  // local notifications a besoin d'un binding initialisé.
  WidgetsFlutterBinding.ensureInitialized();

  // Storage natif (Keychain iOS / EncryptedSharedPreferences Android).
  // En tests on override avec `InMemorySecureStorage` — voir
  // test/features/auth/session_provider_test.dart.
  final storage = SessionStorage(FlutterSecureStorageImpl());
  final db = LocalDatabase();

  final notifPlugin = FlutterLocalNotificationsPlugin();
  final notifService = NotificationsService(notifPlugin);
  await notifService.init();

  runApp(
    ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        localDatabaseProvider.overrideWithValue(db),
        notificationsServiceProvider.overrideWithValue(notifService),
      ],
      child: const PilooApp(),
    ),
  );
}
