// Helpers d'affichage d'une boîte pour le redesign name-first (#370).
//
// Le type Boite ne stocke que le cip13. Le nom vient de la résolution BDPM
// (useBoiteNames) ; à défaut, du préfixe `NOM // notes` (convention du scan
// mobile) ; en dernier recours, du CIP lui-même.
import type { components } from '@piloo/api-client';

type Boite = components['schemas']['Boite'];
type BdpmMedicament = components['schemas']['BdpmMedicament'];

/** Retire le suffixe `, <forme>` de la dénomination BDPM
 * ("DOLIPRANE 1000 mg, comprimé pelliculé" → "DOLIPRANE 1000 mg"). */
export function stripFormeSuffix(denomination: string, forme: string | null): string {
  if (!forme) return denomination;
  const suffix = `, ${forme}`;
  if (denomination.toLowerCase().endsWith(suffix.toLowerCase())) {
    return denomination.slice(0, denomination.length - suffix.length).trim();
  }
  return denomination;
}

/** Extrait le nom du préfixe `NOM // notes libres` (convention scan mobile). */
export function nameFromNotes(notes: string | null): string | null {
  if (!notes) return null;
  const idx = notes.indexOf(' // ');
  if (idx <= 0) return null;
  return notes.slice(0, idx);
}

/**
 * Nom affichable d'une boîte, par priorité décroissante :
 *   1. dénomination BDPM (résolue via cip13), suffixe de forme retiré
 *   2. préfixe `NOM // …` des notes
 *   3. `CIP {cip13}` en dernier recours
 */
export function boiteDisplayName(boite: Boite, med: BdpmMedicament | undefined): string {
  if (med) return stripFormeSuffix(med.denomination, med.forme);
  return nameFromNotes(boite.notes) ?? `CIP ${boite.cip13}`;
}

export type PeremptionSeverity = 'ok' | 'warn' | 'err';

/**
 * Sévérité de la péremption : périmé ou < 7 j → err, < 30 j → warn, sinon ok.
 * Calcul en jours pleins depuis aujourd'hui (date locale).
 */
export function peremptionSeverity(
  peremptionIso: string,
  now: Date = new Date(),
): PeremptionSeverity {
  const perem = new Date(`${peremptionIso.slice(0, 10)}T00:00:00`);
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const days = Math.round((perem.getTime() - today.getTime()) / 86_400_000);
  if (days < 7) return 'err';
  if (days < 30) return 'warn';
  return 'ok';
}

/** Libellé court de péremption ("nov. 2026", "périmé", "dans 6 j"). */
export function formatPeremption(peremptionIso: string, now: Date = new Date()): string {
  const perem = new Date(`${peremptionIso.slice(0, 10)}T00:00:00`);
  if (Number.isNaN(perem.getTime())) return peremptionIso;
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const days = Math.round((perem.getTime() - today.getTime()) / 86_400_000);
  if (days < 0) return 'périmé';
  if (days <= 30) return `dans ${String(days)} j`;
  return perem.toLocaleDateString('fr-FR', { month: 'short', year: 'numeric' });
}

/** Date pleine lisible ("30 nov. 2026"). */
export function formatDateFull(iso: string): string {
  const d = new Date(iso.length >= 10 ? iso.slice(0, 10) : iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
}

/** Badge de statut → tonalité + libellé. */
export function statutBadge(statut: Boite['statut']): {
  tone: 'ok' | 'err' | 'neutral';
  label: string;
} {
  return {
    active: { tone: 'ok' as const, label: 'Active' },
    perimee: { tone: 'err' as const, label: 'Périmée' },
    vide: { tone: 'neutral' as const, label: 'Vide' },
  }[statut];
}
