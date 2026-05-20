// Service FCM (#122 / #128).
//
// Récupère le token FCM du device après init Firebase, l'enregistre
// auprès du backend via POST /v1/devices, écoute les nouveaux tokens
// (rotation) et gère les messages reçus :
//   - foreground : la notif système Android n'est pas affichée par
//     défaut → on relaie vers flutter_local_notifications.
//   - background / opened : payload data utilisé pour deep-link vers
//     l'écran concerné (prise, alerte, etc.) — TODO router.
//
// Distinct du `NotificationsService` qui gère les notifs locales
// scheduled (rappels de prise). FCM = push depuis le serveur (alertes
// proche, manque signalé, stock bas).
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/shared/api/api_client_provider.dart';

class FcmService {
  FcmService({
    required this.fcm,
    required this.localNotifs,
  });

  final FirebaseMessaging fcm;
  final FlutterLocalNotificationsPlugin localNotifs;

  /// Demande la permission iOS (Android l'a via permission_handler).
  /// Doit être appelé une fois après que l'user accepte les notifs
  /// dans PermissionsScreen.
  Future<bool> requestPermission() async {
    final settings = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Récupère le token FCM courant. Peut renvoyer null si permission
  /// refusée, ou si APNs n'est pas encore lié sur iOS (le token FCM
  /// dépend de l'APNs token sur iOS).
  Future<String?> getToken() async {
    try {
      if (Platform.isIOS) {
        // Sur iOS, on doit récupérer le token APNs d'abord — sinon
        // getToken() peut bloquer ou renvoyer null silencieusement.
        await fcm.getAPNSToken();
      }
      return await fcm.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Stream des rotations de token (Firebase peut rafraîchir le token
  /// si l'app reste off longtemps, après backup/restore, etc.).
  Stream<String> get onTokenRefresh => fcm.onTokenRefresh;

  /// Configure les handlers de messages reçus. Appelé une fois au boot.
  void wireMessageHandlers() {
    // Foreground : Android n'affiche pas la notif système, on la relaie
    // via local_notifications pour que l'user la voit même si l'app
    // est ouverte.
    FirebaseMessaging.onMessage.listen(_showLocalForForeground);
    // Background → opened by user : on pourrait deep-link ici.
    // Pour l'instant on log juste — le wiring nav viendra avec
    // l'épisode notif actions rapides (#128).
    FirebaseMessaging.onMessageOpenedApp.listen((_) {});
  }

  Future<void> _showLocalForForeground(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;
    await localNotifs.show(
      msg.hashCode & 0x7fffffff,
      n.title,
      n.body,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          'piloo_fcm',
          'Notifications serveur',
          channelDescription: 'Alertes envoyées par Piloo (stock bas, manque signalé, oublis).',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: msg.data['type'] is String ? msg.data['type'] as String : null,
    );
  }
}

/// POST /v1/devices avec le token FCM. Idempotent côté serveur
/// (UPSERT sur user+token). À appeler après que l'utilisateur soit
/// authentifié (sinon 401) ET que le token soit dispo.
Future<void> registerFcmToken(
  WidgetRef ref, {
  required String token,
  required String appVersion,
}) async {
  final client = ref.read(pilooApiClientProvider).getDevicesApi();
  final builder = api.RegisterDeviceInputBuilder()
    ..token = token
    ..platform = Platform.isIOS
        ? api.RegisterDeviceInputPlatformEnum.ios
        : api.RegisterDeviceInputPlatformEnum.android
    ..appVersion = appVersion;
  await client.v1DevicesPost(registerDeviceInput: builder.build());
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  throw UnimplementedError(
    'fcmServiceProvider must be overridden in main.dart',
  );
});
