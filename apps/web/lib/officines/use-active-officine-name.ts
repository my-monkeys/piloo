// Petit hook : nom de l'officine active (pour les eyebrows de page). #370
'use client';

import { $api } from '@piloo/api-client';

import { useActiveOfficine } from '@/lib/officines/active-officine';

export function useActiveOfficineName(): string | undefined {
  const { activeOfficineId } = useActiveOfficine();
  const { data } = $api.useQuery('get', '/v1/officines');
  const active = data?.items.find((o) => o.id === activeOfficineId) ?? data?.items[0];
  return active?.nom;
}
