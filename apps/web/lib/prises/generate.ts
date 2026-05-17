// Génération des prises_planifiees depuis une prescription (#107).
//
// Algorithme pour le cas "durée fixe" — on crée toutes les occurrences
// d'avance sur la fenêtre [dateDebut, dateDebut + dureeJours). Le cas
// "à vie" (génération glissante) est traité séparément (#108).
//
// Sources d'horaires, par ordre de priorité :
//   1. `posologie.horaires` — heures explicites définies sur la prescription
//      (l'ordonnateur a écrit "08:30 / 14:00 / 22:00"). Si présent, on
//      l'utilise tel quel et on ignore `moments` (saisie explicite > sémantique).
//   2. `posologie.moments` — symboles matin/midi/soir/coucher, mappés sur
//      les heures de l'utilisateur (ou les défauts si pas de pref).
//   3. Aucun des deux → 1 prise/jour à l'heure "matin" par défaut.
//
// La fréquence détermine la cadence :
//   - `quotidien` → tous les jours
//   - `hebdomadaire` → jour 0, +7, +14… dans la durée
//   - `a_la_demande` → aucune prise planifiée (rien à générer)
//
// Les datetimes sont en UTC, calculées depuis `dateDebut` (Date locale du
// patient) + heure de prise. On suppose `dateDebut` à 00:00 dans la TZ
// du patient — l'appelant fournit déjà une Date qui représente minuit local.
import type { NewPrisePlanifiee, Posologie, Prescription } from '@piloo/db-schema';

export type Moment = 'matin' | 'midi' | 'soir' | 'coucher';

/** Heures par défaut si la prescription ne précise rien. */
export const DEFAULT_HORAIRES_BY_MOMENT: Readonly<Record<Moment, string>> = {
  matin: '08:00',
  midi: '12:00',
  soir: '19:00',
  coucher: '22:00',
};

export interface GenerateOptions {
  /** Officine de rattachement (dénormalisée sur prises_planifiees). */
  officineId: string;
  /** Minuit local du premier jour de prise. */
  dateDebut: Date;
  /**
   * Override des horaires user (par moment). Les moments absents
   * retombent sur `DEFAULT_HORAIRES_BY_MOMENT`. Permet de brancher les
   * préférences utilisateur sans changer la signature.
   */
  horairesUtilisateur?: Partial<Record<Moment, string>>;
}

/** Parse `"HH:MM"` → `{ hours, minutes }`. Lance si invalide. */
function parseHoraire(h: string): { hours: number; minutes: number } {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(h);
  if (!match) throw new Error(`horaire invalide: ${h}`);
  return { hours: Number(match[1]), minutes: Number(match[2]) };
}

/**
 * Liste ordonnée des heures de prise (HH:MM) pour un jour donné, dérivée
 * de la posologie + des préférences user. Tri ascendant pour stabilité.
 */
export function buildHorairesForDay(
  posologie: Posologie,
  horairesUtilisateur?: Partial<Record<Moment, string>>,
): string[] {
  if (posologie.horaires && posologie.horaires.length > 0) {
    return [...posologie.horaires].sort();
  }
  if (posologie.moments && posologie.moments.length > 0) {
    const seen = new Set<string>();
    const result: string[] = [];
    for (const m of posologie.moments) {
      const h = horairesUtilisateur?.[m] ?? DEFAULT_HORAIRES_BY_MOMENT[m];
      if (!seen.has(h)) {
        seen.add(h);
        result.push(h);
      }
    }
    return result.sort();
  }
  return [horairesUtilisateur?.matin ?? DEFAULT_HORAIRES_BY_MOMENT.matin];
}

/** Jours offsets (en jours) à partir de dateDebut, selon la fréquence. */
function buildDayOffsets(posologie: Posologie, dureeJours: number): number[] {
  if (posologie.frequence === 'a_la_demande') return [];
  if (dureeJours <= 0) return [];
  if (posologie.frequence === 'hebdomadaire') {
    const offsets: number[] = [];
    for (let d = 0; d < dureeJours; d += 7) offsets.push(d);
    return offsets;
  }
  // quotidien
  return Array.from({ length: dureeJours }, (_, i) => i);
}

/**
 * Compose une Date UTC à partir d'une date "minuit local du patient"
 * et d'un horaire `HH:MM`. On reconstruit avec `setUTCHours` pour rester
 * stable : le caller a déjà choisi la TZ en composant `dateDebut`.
 */
function composeDatetime(dateDebut: Date, dayOffset: number, horaire: string): Date {
  const d = new Date(dateDebut);
  d.setUTCDate(d.getUTCDate() + dayOffset);
  const { hours, minutes } = parseHoraire(horaire);
  d.setUTCHours(hours, minutes, 0, 0);
  return d;
}

/**
 * Génère la liste complète des prises pour une prescription "durée fixe".
 * Retourne un tableau prêt à insérer dans `prises_planifiees`. Lève si
 * la posologie contient un horaire mal formé.
 */
export function generatePrisesForPrescription(
  prescription: Pick<Prescription, 'id' | 'posologie' | 'dureeJours'>,
  options: GenerateOptions,
): NewPrisePlanifiee[] {
  const { posologie, dureeJours } = prescription;
  if (dureeJours === null) return [];

  const horaires = buildHorairesForDay(posologie, options.horairesUtilisateur);
  if (horaires.length === 0) return [];

  const offsets = buildDayOffsets(posologie, dureeJours);
  if (offsets.length === 0) return [];

  const result: NewPrisePlanifiee[] = [];
  for (const offset of offsets) {
    for (const horaire of horaires) {
      result.push({
        prescriptionId: prescription.id,
        officineId: options.officineId,
        datetimePrevue: composeDatetime(options.dateDebut, offset, horaire),
        statut: 'prevue',
      });
    }
  }
  return result;
}

export interface WindowGenerateOptions {
  officineId: string;
  /** Minuit local du premier jour de la fenêtre (inclus). */
  windowStart: Date;
  /** Nombre de jours dans la fenêtre. */
  windowDays: number;
  horairesUtilisateur?: Partial<Record<Moment, string>>;
}

/**
 * Génère les prises sur une fenêtre glissante [windowStart, windowStart +
 * windowDays). Utilisé pour les prescriptions "à vie" (dureeJours = null)
 * via un cron quotidien (#108). Respecte la fréquence : un hebdomadaire
 * dans une fenêtre de 30j produit ~4 prises ; un quotidien en produit 30.
 */
export function generatePrisesForWindow(
  prescription: Pick<Prescription, 'id' | 'posologie'>,
  options: WindowGenerateOptions,
): NewPrisePlanifiee[] {
  const { posologie } = prescription;
  if (options.windowDays <= 0) return [];

  const horaires = buildHorairesForDay(posologie, options.horairesUtilisateur);
  if (horaires.length === 0) return [];

  const offsets = buildDayOffsets(posologie, options.windowDays);
  if (offsets.length === 0) return [];

  const result: NewPrisePlanifiee[] = [];
  for (const offset of offsets) {
    for (const horaire of horaires) {
      result.push({
        prescriptionId: prescription.id,
        officineId: options.officineId,
        datetimePrevue: composeDatetime(options.windowStart, offset, horaire),
        statut: 'prevue',
      });
    }
  }
  return result;
}
