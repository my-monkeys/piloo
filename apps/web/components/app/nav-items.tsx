// Configuration de navigation partagée entre la sidebar (desktop) et la
// tab bar (mobile), pour qu'elles restent cohérentes (#370).
import {
  BellIcon as Bell,
  CalendarDotsIcon as CalendarDots,
  GearIcon as Gear,
  HouseIcon as House,
  type Icon,
  PackageIcon as Package,
  PrescriptionIcon as Prescription,
  UsersThreeIcon as UsersThree,
} from '@phosphor-icons/react';

export interface NavItem {
  href: string;
  label: string;
  Icon: Icon;
  /** Libellé court pour la tab bar mobile (défaut = label). */
  short?: string;
}

/** Nav principale — ordre = ordre d'affichage dans la sidebar. */
export const NAV_MAIN: NavItem[] = [
  { href: '/dashboard', label: 'Tableau de bord', Icon: House, short: 'Accueil' },
  { href: '/timeline', label: 'Timeline', Icon: CalendarDots },
  { href: '/inventory', label: 'Inventaire', Icon: Package },
  { href: '/ordonnances', label: 'Ordonnances', Icon: Prescription },
  { href: '/rappels', label: 'Rappels', Icon: Bell },
];

/** Nav secondaire (bas de sidebar). */
export const NAV_SECONDARY: NavItem[] = [
  { href: '/pro/patients', label: 'Espace pro', Icon: UsersThree },
  { href: '/settings/officines', label: 'Réglages', Icon: Gear },
];

/** Onglets de la tab bar mobile (sous-ensemble des essentiels). */
const TAB_HREFS = ['/dashboard', '/timeline', '/inventory', '/rappels'];
export const TAB_ITEMS: NavItem[] = NAV_MAIN.filter((i) => TAB_HREFS.includes(i.href));
