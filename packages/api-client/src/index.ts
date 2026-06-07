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
// L'instance par défaut utilise baseUrl `/api` — même origin que le front
// (donc les cookies Better Auth HttpOnly sont transmis automatiquement),
// avec le préfixe `/api` car les routes Next.js vivent sous `/api/v1/...`
// alors que le contrat OpenAPI déclare les chemins en `/v1/...` (cf. #353).
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

// Préfixe des routes API Next.js. Le contrat OpenAPI déclare les chemins
// en `/v1/...`, mais Next sert l'API sous `/api/v1/...`. Sans ce préfixe,
// `$api.useQuery('get', '/v1/officines')` tape `/v1/officines` → 404 (#353).
export const API_BASE_PATH = '/api';

// Instance par défaut pour les usages standards (même-origin, cookie auth).
const _defaultClient = createPilooApiClient({ baseUrl: API_BASE_PATH });
export const apiClient = _defaultClient.apiClient;
export const $api = _defaultClient.$api;
