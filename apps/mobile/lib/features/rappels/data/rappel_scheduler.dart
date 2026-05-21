// Scheduler des rappels simples (#327) via flutter_local_notifications.
//
// Stratégie : un rappel = une notif récurrente quotidienne (daily à HH:MM
// local user). On utilise `matchDateTimeComponents: DateTimeComponents.time`
// pour que la même notif se répète chaque jour à l'heure dite sans qu'on
// ait à scheduler N occurrences.
//
// Au launch app et à chaque mutation (create/update/toggle/delete), on
// re-appelle `rescheduleAll(rappels)` qui annule tout et reprogramme à
// partir de la source de vérité serveur. Plus simple à raisonner qu'un
// diff incrémental.
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;
import 'package:timezone/timezone.dart' as tz;

/// Channel Android dédié aux rappels simples — distinct du channel des
/// prises planifiées pour que l'user puisse désactiver les uns sans les
/// autres dans les réglages système.
const _channelId = 'piloo_rappels';
const _channelName = 'Rappels';
const _channelDescription = 'Rappels quotidiens (pilule, vitamines, etc.)';
const _idOffset = 0x40000000;

class RappelScheduler {
  RappelScheduler(this._plugin);
  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> rescheduleAll(List<api.Rappel> rappels) async {
    // Annule uniquement nos notifs (offset stable) plutôt que cancelAll,
    // pour ne pas écraser celles des prises planifiées qui vivent dans
    // un autre namespace d'IDs.
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id >= _idOffset && p.id < _idOffset + 0x10000000) {
        await _plugin.cancel(p.id);
      }
    }
    for (final r in rappels) {
      if (!r.actif) continue;
      await _scheduleOne(r);
    }
  }

  Future<void> _scheduleOne(api.Rappel r) async {
    final parts = r.heure.split(':');
    final hh = int.tryParse(parts.elementAtOrNull(0) ?? '');
    final mm = int.tryParse(parts.elementAtOrNull(1) ?? '');
    if (hh == null || mm == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hh, mm);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      _stableId(r.id),
      r.label,
      "Rappel quotidien — c'est l'heure de prendre ${r.label.toLowerCase()}.",
      next,
      NotificationDetails(
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancel(String rappelId) async {
    await _plugin.cancel(_stableId(rappelId));
  }

  /// ID 32-bit stable dérivé de l'UUID + offset pour éviter de collisionner
  /// avec les IDs des prises planifiées.
  int _stableId(String rappelId) => _idOffset + (rappelId.hashCode & 0x0fffffff);

  Future<void> ensureChannel() async {
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    ));
  }
}
