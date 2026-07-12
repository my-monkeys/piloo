import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/router/router.dart';
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

  // Purge de la session résiduelle au 1er lancement après (ré)installation.
  // Sur iOS, le Keychain survit à la désinstallation de l'app : sans ça, une
  // session périmée d'un ancien install est lue au boot → le splash route vers
  // /today → 1er appel API → 401 → SessionExpiryHandler (#361) bascule vers
  // /welcome, d'où un flash désagréable. Le flag vit dans shared_preferences,
  // qui EST effacé à la désinstallation : son absence = install fraîche (#382).
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool('piloo_installed') ?? false)) {
    await storage.clear();
    await prefs.setBool('piloo_installed', true);
  }

  final db = LocalDatabase();
  // Router instancié ici (vs avant dans _PilooAppState) pour pouvoir
  // l'exposer via routerProvider — l'overlay onboarding (#351) en a
  // besoin pour naviguer entre tabs hors du Navigator.
  final router = buildRouter();

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
        routerProvider.overrideWithValue(router),
      ],
      child: const PilooApp(),
    ),
  );
}
