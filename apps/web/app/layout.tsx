import type { ReactNode } from 'react';

import { CookieBanner } from '@/components/legal/cookie-banner';
import { PilooQueryProvider } from '@/lib/api/query-client-provider';
import { CookieConsentProvider } from '@/lib/cookies/consent';

// Tokens de design générés depuis `packages/design-tokens/tokens.json`.
// Expose les CSS vars `--piloo-*` accessibles partout dans l'app.
import '../styles/tokens.gen.css';
// Tailwind + globals (#56) — doit venir APRÈS tokens.gen.css pour
// pouvoir consommer les vars `--piloo-*` dans @layer base.
import './globals.css';

export const metadata = {
  title: 'Piloo',
  description: 'Carnet numérique de médicaments — aide-mémoire personnel.',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="fr">
      <body>
        <CookieConsentProvider>
          <PilooQueryProvider>{children}</PilooQueryProvider>
          <CookieBanner />
        </CookieConsentProvider>
      </body>
    </html>
  );
}
