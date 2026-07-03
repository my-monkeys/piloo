// Conversions heure murale ⇄ instant UTC pour un fuseau IANA, via Intl
// (DST-aware, sans dépendance). Utilisé pour planifier les prises dans le
// fuseau de l'officine (#363).

/** Décompose un instant en champs muraux (1-based month) dans `timeZone`. */
export function utcToZonedParts(
  instant: Date,
  timeZone: string,
): { year: number; month: number; day: number; hour: number; minute: number } {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  const parts = Object.fromEntries(fmt.formatToParts(instant).map((p) => [p.type, p.value]));
  let hour = Number(parts.hour);
  // Intl peut rendre "24" à minuit selon la locale/env — normaliser.
  if (hour === 24) hour = 0;
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour,
    minute: Number(parts.minute),
  };
}

/** Offset (ms) de `timeZone` à l'instant `date` : local - UTC. */
function tzOffsetMs(date: Date, timeZone: string): number {
  const p = utcToZonedParts(date, timeZone);
  // Instant qui, lu en UTC, a les mêmes champs que l'heure murale locale.
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, 0, 0);
  // Tronquer les secondes/ms de `date` pour comparer au même grain.
  const truncated = Math.floor(date.getTime() / 60_000) * 60_000;
  return asUtc - truncated;
}

/**
 * Instant UTC d'une heure murale (`month` 1-based) dans `timeZone`.
 * Deux passes pour converger sur l'offset correct autour des transitions DST.
 * Cas limites : gap de printemps → l'instant retombe après la transition ;
 * overlap d'automne → première occurrence. Déterministe.
 */
export function zonedWallClockToUtc(
  year: number,
  month: number,
  day: number,
  hours: number,
  minutes: number,
  timeZone: string,
): Date {
  const naiveUtc = Date.UTC(year, month - 1, day, hours, minutes, 0, 0);
  let guess = new Date(naiveUtc - tzOffsetMs(new Date(naiveUtc), timeZone));
  // 2e passe : re-mesure l'offset à l'instant estimé (corrige les bords DST).
  const offset2 = tzOffsetMs(guess, timeZone);
  guess = new Date(naiveUtc - offset2);
  return guess;
}
