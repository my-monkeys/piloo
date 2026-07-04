// Résolution visuelle d'une forme galénique BDPM (#370, redesign web).
//
// La `forme` BDPM est du texte libre ("comprimé pelliculé", "solution
// injectable", "gélule gastro-résistante"…). On la classe par mot-clé —
// même logique que le mobile (`_iconForForme`) — vers une icône Phosphor,
// une teinte (pastille colorée) et un libellé court. Ordre du plus
// spécifique au plus générique pour éviter qu'une forme rare se fasse
// capter par un mot trop large.
import {
  BandaidsIcon as Bandaids,
  DropIcon as Drop,
  EyedropperIcon as Eyedropper,
  FlaskIcon as Flask,
  type Icon,
  PillIcon as Pill,
  SyringeIcon as Syringe,
  WindIcon as Wind,
} from '@phosphor-icons/react';

export type FormeTint = 'tint-oral' | 'tint-inj' | 'tint-top';

export interface FormeVisual {
  Icon: Icon;
  /** Classe de teinte de la pastille (fond + couleur). */
  tint: FormeTint;
  /** Libellé court affichable ("Comprimé", "Solution injectable"…). */
  label: string;
}

const ORAL: FormeTint = 'tint-oral';
const INJ: FormeTint = 'tint-inj';
const TOP: FormeTint = 'tint-top';

/**
 * Classe une forme galénique (texte libre BDPM) en icône + teinte + libellé.
 * `null`/vide → comprimé par défaut (le cas le plus courant, neutre).
 */
export function formeVisual(forme: string | null | undefined): FormeVisual {
  const f = (forme ?? '').toLowerCase();

  if (f.includes('collyre') || f.includes('goutte'))
    return { Icon: Eyedropper, tint: TOP, label: 'Gouttes' };
  if (f.includes('inhal') || f.includes('aérosol') || f.includes('aerosol'))
    return { Icon: Wind, tint: TOP, label: 'Inhalation' };
  if (f.includes('pulvéris') || f.includes('pulveris') || f.includes('spray'))
    return { Icon: Wind, tint: TOP, label: 'Spray' };
  if (f.includes('transdermique') || f.includes('patch') || f.includes('dispositif'))
    return { Icon: Bandaids, tint: TOP, label: 'Patch' };
  if (f.includes('injectable') || f.includes('perfusion') || f.includes('sous-cutané'))
    return { Icon: Syringe, tint: INJ, label: 'Solution injectable' };
  if (
    f.includes('crème') ||
    f.includes('creme') ||
    f.includes('pommade') ||
    f.includes('gel ') ||
    f.includes('application') ||
    f.includes('cutané')
  )
    return { Icon: Drop, tint: TOP, label: 'Crème / pommade' };
  if (f.includes('sirop') || f.includes('buvable') || f.includes('suspension'))
    return { Icon: Flask, tint: ORAL, label: 'Sirop / buvable' };
  if (f.includes('poudre') || f.includes('sachet') || f.includes('granulé'))
    return { Icon: Flask, tint: ORAL, label: 'Poudre / sachet' };
  if (f.includes('gélule') || f.includes('gelule') || f.includes('capsule'))
    return { Icon: Pill, tint: ORAL, label: 'Gélule' };

  // Comprimé + tout solide ingérable non reconnu → pilule (choix neutre).
  return { Icon: Pill, tint: ORAL, label: 'Comprimé' };
}

/** Classes Tailwind pour chaque teinte (fond + texte). */
export const TINT_CLASSES: Record<FormeTint, string> = {
  'tint-oral': 'bg-piloo-primary-soft text-piloo-primary-hover',
  'tint-inj': 'bg-piloo-accent-soft text-piloo-accent',
  'tint-top': 'bg-[var(--piloo-color-info)] text-[var(--piloo-color-info-on)]',
};
