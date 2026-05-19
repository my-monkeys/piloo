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
// Permissions :
//   - iOS : `requestPermissions()` → alert+badge+sound, déclenché à
//     l'onboarding par PermissionsScreen (#67).
//   - Android 13+ : POST_NOTIFICATIONS permission, idem.
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Channel Android dédié aux rappels de prise (HIGH importance → heads-up).
const _channelId = 'piloo_prises';
const _channelName = 'Rappels de prise';
const _channelDescription =
    'Notifications pour vous rappeler de prendre vos médicaments à l\'heure prévue.';

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

    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        // Pas de request à l'init : on attend l'écran Permissions du
        // welcome pour demander explicitement.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(initSettings);

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
  Future<void> scheduleForPrises(List<api.PriseTimelineItem> prises) async {
    await _plugin.cancelAll();
    final now = DateTime.now();
    for (final p in prises) {
      if (p.statut != api.PriseTimelineItemStatutEnum.prevue) continue;
      final scheduled = p.datetimePrevue.toLocal();
      if (scheduled.isBefore(now)) continue;
      await _scheduleOne(p, scheduled);
    }
  }

  Future<void> _scheduleOne(api.PriseTimelineItem p, DateTime scheduled) async {
    final tzScheduled = tz.TZDateTime.from(scheduled, tz.local);
    final hh = scheduled.hour.toString().padLeft(2, '0');
    final mm = scheduled.minute.toString().padLeft(2, '0');
    final title = p.prescription.nomTexte;
    final body = "Prise prévue à $hh:$mm — pense à valider dans l'app.";
    await _plugin.zonedSchedule(
      _stableId(p.id),
      title,
      body,
      tzScheduled,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      // Le payload sert à reconnaître l'origine quand l'utilisateur
      // tape la notif (deeplink futur vers /today).
      payload: 'prise:${p.id}',
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

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  throw UnimplementedError(
    'notificationsServiceProvider must be overridden in main.dart',
  );
});
