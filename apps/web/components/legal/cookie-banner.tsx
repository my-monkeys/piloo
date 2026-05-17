// Banner cookies (#160). Posé en bas-fixed jusqu'à choix utilisateur.
//
// AC :
//  - Refus = strict minimum → bouton "Refuser" ne pose que les cookies
//    essentiels (déjà actifs de toute façon), opt-out analytics.
//  - Préférences modifiables → lien vers /legal/cookies.
'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

import { Button } from '@/components/ui/button';
import { useCookieConsent } from '@/lib/cookies/consent';

export function CookieBanner() {
  const { consent, setConsent } = useCookieConsent();
  // Délai d'1 tick post-mount pour éviter le flash SSR — `consent` est
  // `null` avant et après `readCookie()` quand l'utilisateur n'a pas
  // encore choisi, donc on ne peut pas distinguer "pas encore lu" de
  // "vraiment vide". Ce flag explicite résout l'ambiguïté.
  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted || consent !== null) return null;

  return (
    <div
      role="dialog"
      aria-live="polite"
      aria-label="Bannière de consentement aux cookies"
      className="fixed inset-x-0 bottom-0 z-50 border-t border-border bg-piloo-surface shadow-lg"
    >
      <div className="container mx-auto max-w-4xl flex flex-col gap-3 p-4 md:flex-row md:items-center md:justify-between">
        <p className="text-sm text-foreground">
          Piloo utilise uniquement des cookies <strong>strictement nécessaires</strong> (session,
          préférence d&apos;officine active). Pas de tracking tiers.{' '}
          <Link href="/legal/cookies" className="underline">
            En savoir plus
          </Link>
          .
        </p>
        <div className="flex gap-2 shrink-0">
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              setConsent({ analytics: false });
            }}
          >
            Refuser
          </Button>
          <Button
            size="sm"
            onClick={() => {
              setConsent({ analytics: true });
            }}
          >
            Accepter
          </Button>
        </div>
      </div>
    </div>
  );
}
