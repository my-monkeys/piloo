// Helpers d'affichage d'une officine (avatar, rôle, type) — partagés entre
// la sidebar, le switcher et la top bar mobile (#370).
import { HouseIcon as House, type Icon, UserIcon as User } from '@phosphor-icons/react';
import type { components } from '@piloo/api-client';

type Officine = components['schemas']['Officine'];

export function roleLabel(role: Officine['role']): string {
  return { owner: 'Propriétaire', editor: 'Éditeur', viewer: 'Lecteur' }[role];
}

export function typeLabel(type: Officine['type']): string {
  return type === 'perso' ? 'Mon carnet' : 'Patient suivi';
}

export interface OfficineAvatar {
  Icon: Icon;
  /** Classe de teinte de l'avatar. */
  cls: string;
}

export function officineAvatar(type: Officine['type']): OfficineAvatar {
  return type === 'perso'
    ? { Icon: House, cls: 'bg-piloo-primary-soft text-piloo-primary-hover' }
    : { Icon: User, cls: 'bg-piloo-accent-soft text-piloo-accent' };
}
