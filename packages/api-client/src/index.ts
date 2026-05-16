// Client HTTP typé pour l'API Piloo (#41).
//
// Composé de trois briques fines :
//   - `apiClient` : openapi-fetch — wrapper typé sur `fetch`, infère
//     les types des paths/réponses depuis `./generated/types`.
//   - `$api`     : openapi-react-query — adapter qui expose `useQuery`,
//     `useMutation`, etc. avec inférence de types par endpoint.
//   - `paths`/`components` : types bruts du contrat OpenAPI, à
//     ré-utiliser dans les composants si besoin (formulaires, etc.).
//
// Usage côté apps/web (client component) :
//   const { data, error } = $api.useQuery('get', '/v1/officines');
//
// Le baseUrl est relatif — Next.js sert l'API sur le même origin que
// le front, donc les cookies Better Auth (HttpOnly) sont transmis
// automatiquement.
import createFetchClient from 'openapi-fetch';
import createReactQueryClient from 'openapi-react-query';

import type { paths } from './generated/types';

export type { paths, components, operations } from './generated/types';

export interface CreatePilooApiClientOptions {
  /** Base URL absolue. Vide ou non-défini = relatif (même origin). */
  baseUrl?: string;
  /** Override pour tests / SSR — injecte une fonction `fetch` custom. */
  fetch?: typeof fetch;
}

export function createPilooApiClient(options: CreatePilooApiClientOptions = {}) {
  const apiClient = createFetchClient<paths>({
    baseUrl: options.baseUrl ?? '',
    // Better Auth pose un cookie HttpOnly `better-auth.session_token` ;
    // `same-origin` (défaut de fetch) le transmet automatiquement.
    credentials: 'same-origin',
    fetch: options.fetch,
  });
  const $api = createReactQueryClient(apiClient);
  return { apiClient, $api };
}

// Instance par défaut pour les usages standards (même-origin, cookie auth).
const _defaultClient = createPilooApiClient();
export const apiClient = _defaultClient.apiClient;
export const $api = _defaultClient.$api;
