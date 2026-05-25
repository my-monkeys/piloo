import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/data/session_storage.dart';
import 'features/auth/presentation/session_provider.dart';
import 'features/onboarding/data/demo_mode_provider.dart';
import 'firebase_options.dart';
import 'shared/db/db_provider.dart';
import 'shared/db/local_db.dart';
import 'shared/notifications/fcm_service.dart';
import 'shared/notifications/notifications_service.dart';

/// Handler background obligatoire — DOIT être top-level (cf. doc
/// firebase_messaging) car Flutter ré-instancie un isolate.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // Pour l'instant on no-op : la notif système est affichée par FCM
  // tout seul en background. Si on veut faire du traitement custom
  // (ex: invalider un cache), c'est ici.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  // setSurfaceSize() côté tests sinon binding null — l'init du plugin
  // local notifications a besoin d'un binding initialisé.
  WidgetsFlutterBinding.ensureInitialized();

  // Storage natif (Keychain iOS / EncryptedSharedPreferences Android).
  // En tests on override avec `InMemorySecureStorage` — voir
  // test/features/auth/session_provider_test.dart.
  final secureStorage = FlutterSecureStorageImpl();
  final storage = SessionStorage(secureStorage);
  final db = LocalDatabase();

  final notifPlugin = FlutterLocalNotificationsPlugin();
  final notifService = NotificationsService(notifPlugin);
  await notifService.init();

  // Firebase + FCM (#122). Init Firebase + register background handler.
  // FcmService.wireMessageHandlers() est appelé par l'app shell pour
  // ne pas dépendre du timing init dans main.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  final fcm = FcmService(fcm: FirebaseMessaging.instance, localNotifs: notifPlugin);
  fcm.wireMessageHandlers();

  runApp(
    ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        secureStorageProvider.overrideWithValue(secureStorage),
        localDatabaseProvider.overrideWithValue(db),
        notificationsServiceProvider.overrideWithValue(notifService),
        fcmServiceProvider.overrideWithValue(fcm),
      ],
      child: const PilooApp(),
    ),
  );
}
