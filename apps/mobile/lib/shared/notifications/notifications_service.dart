// Service de notifications locales pour les rappels de prise (#128).
//
// Pourquoi local et pas push serveur :
//   - L'app a déjà toutes les données nécessaires localement (timeline
//     du jour via prisesDayProvider).
//   - Pas de coût Firebase, pas de dépendance réseau au moment du
//     rappel — l'utilisateur est notifié même hors-ligne.
//   - Plus simple à itérer pour le MVP : FCM peut s'ajouter plus tard
//     pour les alertes serveur (stock bas, péremption proche).
//
// Stratégie :
//   - 1 notification par PriseTimelineItem en statut `pending`.
//   - ID stable dérivé de l'UUID Prise (hashCode tronqué) pour pouvoir
//     l'annuler/replanifier sans dupliquer.
//   - Quand l'utilisateur valide une prise via PATCH /v1/prises/{id},
//     la notification correspondante est annulée.
//
// Actions rapides (#128) :
//   - 3 boutons sur la notif : Prise / Sauter / +15min.
//   - Le tap d'une action écrit dans pending_operations directement
//     depuis le callback — aucune ouverture de l'app requise.
//   - iOS : un UNNotificationCategory "rappel_prise" est enregistré au
//     boot avec les 3 actions.
//   - Android : les 3 actions sont injectées par notification.
//
// Permissions :
//   - iOS : `requestPermissions()` → alert+badge+sound, déclenché à
//     l'onboarding par PermissionsScreen (#67).
//   - Android 13+ : POST_NOTIFICATIONS permission, idem.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:piloo/shared/notifications/prise_action_handler.dart';

/// Channel Android dédié aux rappels de prise (HIGH importance → heads-up).
const _channelId = 'piloo_prises';
const _channelName = 'Rappels de prise';
const _channelDescription =
    'Notifications pour vous rappeler de prendre vos médicaments à l\'heure prévue.';

/// Catégorie iOS qui groupe les 3 actions Prise/Sauter/+15min (#128).
/// Le category identifier est passé par chaque notif via
/// `DarwinNotificationDetails.categoryIdentifier`.
const _iosPriseCategoryId = 'rappel_prise';

class NotificationsService {
  NotificationsService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// Initialise le plugin + la timezone locale. À appeler une fois au
  /// boot dans `main.dart` AVANT le premier usage.
  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Fallback : UTC. Mieux que crasher au boot — l'utilisateur
      // recevra ses notifs au mauvais moment mais ne perd pas l'app.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    final initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        // Pas de request à l'init : on attend l'écran Permissions du
        // welcome pour demander explicitement.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: _buildIosCategories(),
      ),
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      initSettings,
      // Foreground / background-when-not-killed : callback in-process.
      onDidReceiveNotificationResponse: _onForegroundActionTap,
      // App tuée : Flutter ré-instancie un isolate, callback DOIT être
      // top-level + annotée @pragma('vm:entry-point').
      onDidReceiveBackgroundNotificationResponse: handlePriseActionBackground,
    );

    // Pré-créer le channel Android (idempotent).
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    ));
  }

  /// Demande explicitement les permissions OS. Idempotent.
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  /// Replanifie toutes les notifs pour les prises données. Annule
  /// d'abord toutes les notifs Piloo en cours pour éviter les doublons
  /// (les IDs sont dérivés du Prise.id donc même prise = même ID, mais
  /// si une prise disparaît du backend on doit nettoyer aussi).
  Future<void> scheduleForPrises(
    List<api.PriseTimelineItem> prises,
    String timeZone,
  ) async {
    await _plugin.cancelAll();
    final now = DateTime.now();
    for (final p in prises) {
      if (p.statut != api.PriseTimelineItemStatutEnum.prevue) continue;
      final scheduled = p.datetimePrevue.toLocal();
      if (scheduled.isBefore(now)) continue;
      await _scheduleOne(p, scheduled, timeZone);
    }
  }

  Future<void> _scheduleOne(
    api.PriseTimelineItem p,
    DateTime scheduled,
    String timeZone,
  ) async {
    // Planification à l'instant absolu (le token est un vrai instant UTC).
    final tzScheduled = tz.TZDateTime.from(scheduled, tz.local);
    // Libellé affiché dans le fuseau de l'officine, pas du téléphone (#363).
    final wall = tz.TZDateTime.from(p.datetimePrevue, tz.getLocation(timeZone));
    final hh = wall.hour.toString().padLeft(2, '0');
    final mm = wall.minute.toString().padLeft(2, '0');
    final title = p.prescription.nomTexte;
    final body = "Prise prévue à $hh:$mm — pense à valider dans l'app.";
    // Payload JSON pour transporter priseId + datetime original (utile
    // pour calculer "+15min" sans roundtrip DB côté background isolate).
    final payload = jsonEncode({
      'priseId': p.id,
      'dt': scheduled.toUtc().toIso8601String(),
    });
    await _plugin.zonedSchedule(
      _stableId(p.id),
      title,
      body,
      tzScheduled,
      NotificationDetails(
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: _iosPriseCategoryId,
        ),
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          actions: _androidPriseActions(),
        ),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Annule la notif d'une prise (appelé après PATCH success
  /// statut=prise/sautee).
  Future<void> cancelForPrise(String priseId) async {
    await _plugin.cancel(_stableId(priseId));
  }

  /// ID 32-bit stable dérivé de l'UUID. flutter_local_notifications
  /// veut un int ; hashCode tronqué à 31 bits évite les collisions
  /// négatives sur Android.
  int _stableId(String priseId) => priseId.hashCode & 0x7fffffff;
}

/// Catégorie iOS "rappel_prise" avec 3 actions Prise/Sauter/+15min (#128).
/// Inscrite au boot via DarwinInitializationSettings.notificationCategories.
List<DarwinNotificationCategory> _buildIosCategories() {
  return [
    DarwinNotificationCategory(
      _iosPriseCategoryId,
      actions: [
        DarwinNotificationAction.plain(
          priseActionMarkPrise,
          'Pris(e)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.authenticationRequired,
          },
        ),
        DarwinNotificationAction.plain(
          priseActionMarkSautee,
          'Sauter',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
        DarwinNotificationAction.plain(
          priseActionSnooze15,
          '+15 min',
          options: const <DarwinNotificationActionOption>{},
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    ),
  ];
}

/// Actions Android attachées à chaque notif rappel_prise (#128).
List<AndroidNotificationAction> _androidPriseActions() {
  return const [
    AndroidNotificationAction(
      priseActionMarkPrise,
      'Pris(e)',
      showsUserInterface: false,
      cancelNotification: true,
    ),
    AndroidNotificationAction(
      priseActionMarkSautee,
      'Sauter',
      showsUserInterface: false,
      cancelNotification: true,
    ),
    AndroidNotificationAction(
      priseActionSnooze15,
      '+15 min',
      showsUserInterface: false,
      cancelNotification: true,
    ),
  ];
}

/// Callback foreground / background-running. Délègue au même handler
/// top-level que celui utilisé quand l'app est tuée — comme ça la logique
/// d'écriture dans pending_operations est unique.
@pragma('vm:entry-point')
void _onForegroundActionTap(NotificationResponse response) {
  // On délègue intentionnellement au handler "background" : il ouvre
  // sa propre instance Drift et clôt. C'est suffisant aussi quand l'app
  // est ouverte : la prochaine invalidation de prisesDayProvider verra
  // le nouvel état (le mirror local est mis à jour avant l'enqueue).
  WidgetsFlutterBinding.ensureInitialized();
  handlePriseActionBackground(response);
}

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  throw UnimplementedError(
    'notificationsServiceProvider must be overridden in main.dart',
  );
});
