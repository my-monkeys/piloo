# Instructions Claude Code — packages/api-client

Client HTTP typé pour consommer l'API Piloo côté `apps/web` (#41).

## Stack

- **`openapi-typescript`** (dev) : génère les types TS depuis `openapi.yaml`.
- **`openapi-fetch`** : wrapper typé sur `fetch`, paths inférés.
- **`openapi-react-query`** : adapter pour TanStack Query — hooks `useQuery`/`useMutation` typés par endpoint.
- **`@tanstack/react-query`** (peer) : à installer côté app consommateur.

## Comment ça génère

Les types sont générés depuis `packages/api-contract/openapi.yaml` par
`scripts/generate-ts-client.sh` et écrits dans `src/generated/types.ts`.

```bash
pnpm openapi:generate-ts-client
```

Le fichier `generated/types.ts` est commité — il fait office de source de
vérité côté front et garantit que `tsc` peut tourner sans pipeline en CI
sans regénérer.

## Comment l'utiliser côté apps/web

```tsx
import { $api } from '@piloo/api-client';

export function OfficinesList() {
  const { data, error, isLoading } = $api.useQuery('get', '/v1/officines');
  if (isLoading) return <Spinner />;
  if (error) return <ErrorBoundary error={error} />;
  return data?.items.map((o) => <OfficineCard key={o.id} officine={o} />);
}
```

Le `QueryClientProvider` doit être posé au root de l'app — typiquement
dans `apps/web/app/layout.tsx`. Voir la doc officielle TanStack Query.

## Conventions

- Les types `paths`, `components`, `operations` sont ré-exportés depuis
  l'index — utiliser `components['schemas']['Officine']` plutôt que
  redéfinir des modèles.
- Pas d'appel direct à `fetch` dans `apps/web` — toujours passer par
  `apiClient` ou `$api` pour conserver le typage.
- Pour les Server Components Next.js, préférer un appel direct à Drizzle
  (cf. `apps/web/CLAUDE.md`) ; ce client est conçu pour les Client
  Components.
