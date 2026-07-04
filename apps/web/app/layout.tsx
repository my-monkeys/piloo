import { Fraunces, Manrope, Spline_Sans_Mono } from 'next/font/google';
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

// Polices auto-hébergées par next/font (aucun appel tiers au runtime —
// conforme au « pas de tracker tiers » sur données de santé). Exposées en
// CSS vars consommées par tailwind.config (font-sans / font-display / font-mono).
const manrope = Manrope({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700', '800'],
  variable: '--font-sans',
  display: 'swap',
});
const fraunces = Fraunces({
  subsets: ['latin'],
  weight: ['400', '500', '600'],
  variable: '--font-display',
  display: 'swap',
});
const splineMono = Spline_Sans_Mono({
  subsets: ['latin'],
  weight: ['400', '500'],
  variable: '--font-mono',
  display: 'swap',
});

export const metadata = {
  title: 'Piloo',
  description: 'Carnet numérique de médicaments — aide-mémoire personnel.',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="fr" className={`${manrope.variable} ${fraunces.variable} ${splineMono.variable}`}>
      <body>
        <CookieConsentProvider>
          <PilooQueryProvider>{children}</PilooQueryProvider>
          <CookieBanner />
        </CookieConsentProvider>
      </body>
    </html>
  );
}
