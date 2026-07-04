// Résolution des noms de médicaments pour une liste de boîtes (#370).
//
// Le type Boite ne stocke que le cip13 ; ce hook appelle l'endpoint batch
// /v1/bdpm/resolve pour récupérer dénomination/forme/dosage/voie/titulaire,
// et renvoie une Map cip13 → médicament. Un CIP inconnu (médoc rare, hors
// base) est absent de la Map → l'UI retombe proprement sur le CIP.
'use client';

import { $api, type components } from '@piloo/api-client';
import { useMemo } from 'react';

export type BdpmMedicament = components['schemas']['BdpmMedicament'];

export interface BoiteNames {
  /** Map cip13 → médicament BDPM résolu. */
  byCip: Map<string, BdpmMedicament>;
  isLoading: boolean;
}

export function useBoiteNames(cip13s: string[]): BoiteNames {
  // Clé stable + dédupliquée : trie pour que l'ordre des boîtes ne change
  // pas la query key (évite des refetch inutiles).
  const cipsParam = useMemo(() => [...new Set(cip13s)].sort().join(','), [cip13s]);

  const { data, isLoading } = $api.useQuery(
    'get',
    '/v1/bdpm/resolve',
    { params: { query: { cips: cipsParam } } },
    { enabled: cipsParam.length > 0, staleTime: 5 * 60_000 },
  );

  const byCip = useMemo(() => {
    const map = new Map<string, BdpmMedicament>();
    for (const med of data?.items ?? []) {
      if (med.cip13) map.set(med.cip13, med);
    }
    return map;
  }, [data]);

  return { byCip, isLoading: cipsParam.length > 0 && isLoading };
}
