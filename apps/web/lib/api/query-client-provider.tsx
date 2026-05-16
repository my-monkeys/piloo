// QueryClientProvider monté au root de l'app (#41).
//
// `'use client'` obligatoire car QueryClientProvider est un Provider
// React qui s'appuie sur Context — ne fonctionne pas dans un Server
// Component. On garde le composant minimal ; le layout root reste un
// Server Component qui le wraps autour des `{children}`.
//
// Une seule instance de `QueryClient` est créée par session client
// grâce à `useState` (évite les recréations à chaque render).
'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { type ReactNode, useState } from 'react';

export function PilooQueryProvider({ children }: { children: ReactNode }) {
  const [client] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            // Données médicales : on évite le refetch trop agressif au
            // mount (les écrans timeline/officines lisent souvent).
            staleTime: 30_000,
            retry: 1,
          },
        },
      }),
  );
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}
