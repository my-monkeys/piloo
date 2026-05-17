// Utilitaires timeline (#172). Groupage par moment de la journée +
// navigation semaine ISO (lundi → dimanche).
//
// Pourquoi on déduit le moment à partir de l'heure plutôt que de le
// stocker en DB : la posologie côté prescription exprime déjà des
// `moments` symboliques (matin/midi/soir/coucher) ; les prises
// planifiées matérialisent ces moments en `datetime_prevue` selon les
// horaires user. Re-déduire le moment depuis l'heure permet de grouper
// la timeline sans alourdir le wire format.

export type Moment = 'matin' | 'midi' | 'soir' | 'coucher';

export const MOMENTS: readonly Moment[] = ['matin', 'midi', 'soir', 'coucher'];

export const MOMENT_LABELS: Record<Moment, string> = {
  matin: 'Matin',
  midi: 'Midi',
  soir: 'Soir',
  coucher: 'Coucher',
};

/** Déduit le moment depuis l'heure ISO (UTC) de la prise. */
export function momentForIso(iso: string): Moment {
  const hour = new Date(iso).getUTCHours();
  if (hour >= 5 && hour < 12) return 'matin';
  if (hour >= 12 && hour < 16) return 'midi';
  if (hour >= 16 && hour < 22) return 'soir';
  return 'coucher';
}

/** Premier jour de la semaine ISO (lundi) qui contient `date`. */
export function startOfIsoWeek(date: Date): Date {
  const d = new Date(date);
  d.setUTCHours(0, 0, 0, 0);
  // getUTCDay() : 0=dimanche, 1=lundi… On veut décaler pour tomber sur lundi.
  const day = d.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setUTCDate(d.getUTCDate() + diff);
  return d;
}

/** Renvoie les 7 jours (lundi → dimanche) au format ISO YYYY-MM-DD. */
export function isoWeekDays(start: Date): readonly string[] {
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(start);
    d.setUTCDate(d.getUTCDate() + i);
    return d.toISOString().slice(0, 10);
  });
}

/** Décale une date d'un nombre de semaines (positif ou négatif). */
export function addWeeks(date: Date, weeks: number): Date {
  const d = new Date(date);
  d.setUTCDate(d.getUTCDate() + weeks * 7);
  return d;
}
