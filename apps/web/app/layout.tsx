import type { ReactNode } from 'react';

import { PilooQueryProvider } from '@/lib/api/query-client-provider';

// Tokens de design générés depuis `packages/design-tokens/tokens.json`.
// Expose les CSS vars `--piloo-*` accessibles partout dans l'app.
import '../styles/tokens.gen.css';

export const metadata = {
  title: 'Piloo',
  description: 'Carnet numérique de médicaments — aide-mémoire personnel.',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="fr">
      <body>
        <PilooQueryProvider>{children}</PilooQueryProvider>
      </body>
    </html>
  );
}
