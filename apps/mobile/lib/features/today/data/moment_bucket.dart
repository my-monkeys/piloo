// Créneau + libellé d'heure d'une prise, calculés dans le fuseau de
// l'officine (#363). `datetimePrevue` est un vrai instant UTC ; on le rend
// dans le fuseau de l'officine (pas celui du téléphone) pour que le créneau
// et l'heure affichée correspondent à ce que vit le patient.
import 'package:timezone/timezone.dart' as tz;

enum Moment { matin, midi, soir, coucher }

/// Convertit l'instant UTC en heure murale du fuseau `timeZone`.
tz.TZDateTime _local(DateTime instantUtc, String timeZone) =>
    tz.TZDateTime.from(instantUtc, tz.getLocation(timeZone));

/// Créneau de la prise selon l'heure locale officine (defaults 08/12/19/22).
Moment momentBucketFor(DateTime instantUtc, String timeZone) {
  final local = _local(instantUtc, timeZone);
  return switch (local.hour) {
    < 12 => Moment.matin,
    < 16 => Moment.midi,
    < 21 => Moment.soir,
    _ => Moment.coucher,
  };
}

/// Libellé `HH:mm` de la prise dans le fuseau officine.
String wallClockLabel(DateTime instantUtc, String timeZone) {
  final local = _local(instantUtc, timeZone);
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
