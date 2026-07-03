// Tests du bucketing/libellé des prises en fuseau officine (#363).
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'package:piloo/features/today/data/moment_bucket.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('coucher 20:00Z en Europe/Paris (été) → Coucher, 22:00', () {
    final instant = DateTime.parse('2026-07-03T20:00:00.000Z');
    expect(momentBucketFor(instant, 'Europe/Paris'), Moment.coucher);
    expect(wallClockLabel(instant, 'Europe/Paris'), '22:00');
  });

  test('soir 17:00Z en Europe/Paris (été) → Soir, 19:00', () {
    final instant = DateTime.parse('2026-07-03T17:00:00.000Z');
    expect(momentBucketFor(instant, 'Europe/Paris'), Moment.soir);
    expect(wallClockLabel(instant, 'Europe/Paris'), '19:00');
  });

  test('matin 06:00Z en Europe/Paris (été) → Matin, 08:00', () {
    final instant = DateTime.parse('2026-07-03T06:00:00.000Z');
    expect(momentBucketFor(instant, 'Europe/Paris'), Moment.matin);
    expect(wallClockLabel(instant, 'Europe/Paris'), '08:00');
  });

  test('même instant 20:00Z lu en UTC → Soir, 20:00 (le fuseau compte)', () {
    final instant = DateTime.parse('2026-07-03T20:00:00.000Z');
    expect(momentBucketFor(instant, 'UTC'), Moment.soir);
    expect(wallClockLabel(instant, 'UTC'), '20:00');
  });
}
