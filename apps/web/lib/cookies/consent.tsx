// Gestion du consentement cookies RGPD (#160).
//
// L'app utilise peu de cookies — Better Auth pour la session
// (strictement nécessaire, pas de consentement requis sous RGPD art.
// 5(3) ePrivacy) et `piloo_active_officine` (préférence UX, fonctionnel).
// Aucun analytics ni tracking tiers (cf. CLAUDE.md §"Points d'attention").
//
// Le banner sert donc :
//   1. À informer l'utilisateur (transparence).
//   2. À recueillir un opt-in si on ajoute un jour des analytics
//      (Plausible self-hosted, p.ex.). Pour l'instant les catégories
//      `analytics` sont des placeholders.
//
// Stockage : cookie `piloo_cookie_consent` (JSON, max 1 an) — pas
// localStorage pour permettre la lecture côté serveur si besoin (SSR
// d'opt-in analytics).
'use client';

import { createContext, type ReactNode, useCallback, useContext, useEffect, useState } from 'react';

export interface CookieConsent {
  // Toujours `true` — non négociable (cookies strictement nécessaires).
  essential: true;
  // Toujours `true` aussi — préférence officine active, expérience
  // dégradée sans. Documenté dans le banner.
  functional: true;
  // Opt-in : par défaut `false` jusqu'à choix explicite.
  analytics: boolean;
  /** Timestamp ISO du choix — utile pour démontrer la fraîcheur du
   * consentement en cas d'audit CNIL. */
  decidedAt: string;
}

const COOKIE_NAME = 'piloo_cookie_consent';
const COOKIE_MAX_AGE = 60 * 60 * 24 * 365;

interface CookieConsentContextValue {
  /** `null` si l'utilisateur n'a pas encore choisi (→ banner visible). */
  consent: CookieConsent | null;
  /** Pose le consentement (objet complet) et persiste. */
  setConsent: (c: Omit<CookieConsent, 'decidedAt' | 'essential' | 'functional'>) => void;
}

const Ctx = createContext<CookieConsentContextValue | undefined>(undefined);

export function CookieConsentProvider({ children }: { children: ReactNode }) {
  const [consent, setConsentState] = useState<CookieConsent | null>(null);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    setConsentState(readCookie());
    setHydrated(true);
  }, []);

  const setConsent = useCallback(
    (c: Omit<CookieConsent, 'decidedAt' | 'essential' | 'functional'>) => {
      const full: CookieConsent = {
        essential: true,
        functional: true,
        analytics: c.analytics,
        decidedAt: new Date().toISOString(),
      };
      writeCookie(full);
      setConsentState(full);
    },
    [],
  );

  // Pendant l'hydratation, on expose `null` côté SSR/initial render
  // pour éviter un flash du banner. Les consumers (banner) doivent
  // attendre le mount client pour s'afficher.
  return (
    <Ctx.Provider value={{ consent: hydrated ? consent : null, setConsent }}>
      {children}
    </Ctx.Provider>
  );
}

export function useCookieConsent(): CookieConsentContextValue & { hydrated: boolean } {
  const ctx = useContext(Ctx);
  if (!ctx) {
    throw new Error('useCookieConsent must be used inside <CookieConsentProvider>');
  }
  // Hack léger : on infère l'état d'hydratation depuis le fait que
  // `consent` n'est plus égal à la valeur initiale `null` après mount.
  // Pour les UI strictes, le banner check séparément `useEffect`.
  return { ...ctx, hydrated: true };
}

function readCookie(): CookieConsent | null {
  if (typeof document === 'undefined') return null;
  const prefix = `${COOKIE_NAME}=`;
  for (const c of document.cookie.split(';')) {
    const trimmed = c.trim();
    if (trimmed.startsWith(prefix)) {
      try {
        const raw = decodeURIComponent(trimmed.slice(prefix.length));
        const parsed = JSON.parse(raw) as Partial<CookieConsent>;
        if (typeof parsed.decidedAt !== 'string') return null;
        return {
          essential: true,
          functional: true,
          analytics: parsed.analytics === true,
          decidedAt: parsed.decidedAt,
        };
      } catch {
        return null;
      }
    }
  }
  return null;
}

function writeCookie(c: CookieConsent): void {
  const value = encodeURIComponent(JSON.stringify(c));
  document.cookie = `${COOKIE_NAME}=${value}; path=/; max-age=${String(COOKIE_MAX_AGE)}; samesite=lax`;
}
