// Officine active courante (#73). Persistée dans un cookie côté client
// pour survivre aux navigations / refresh — accessible aussi côté serveur
// si un jour on en a besoin (cf. layout SSR).
//
// Pas de Zustand pour cette pièce (un seul état trivial). Context React
// suffit. L'API est `useActiveOfficine()` + `setActive(id)`.
//
// Le cookie est `same-site` par défaut, scopé `/`, sans HttpOnly (le
// JS client lit/écrit). Pas d'info sensible — juste un UUID.
'use client';

import { createContext, type ReactNode, useCallback, useContext, useEffect, useState } from 'react';

const COOKIE_NAME = 'piloo_active_officine';
const COOKIE_MAX_AGE = 60 * 60 * 24 * 365; // 1 an

interface ActiveOfficineContextValue {
  activeOfficineId: string | null;
  setActive: (id: string | null) => void;
}

const Ctx = createContext<ActiveOfficineContextValue | undefined>(undefined);

export function ActiveOfficineProvider({
  children,
  initial,
}: {
  children: ReactNode;
  initial?: string | null;
}) {
  const [activeOfficineId, setActiveOfficineId] = useState<string | null>(initial ?? null);

  // Hydrate depuis le cookie au mount (si pas d'initial fourni par SSR).
  useEffect(() => {
    if (initial !== undefined) return;
    const fromCookie = readCookie(COOKIE_NAME);
    if (fromCookie) setActiveOfficineId(fromCookie);
  }, [initial]);

  const setActive = useCallback((id: string | null) => {
    setActiveOfficineId(id);
    if (id) {
      document.cookie = `${COOKIE_NAME}=${id}; path=/; max-age=${String(COOKIE_MAX_AGE)}; samesite=lax`;
    } else {
      document.cookie = `${COOKIE_NAME}=; path=/; max-age=0`;
    }
  }, []);

  return <Ctx.Provider value={{ activeOfficineId, setActive }}>{children}</Ctx.Provider>;
}

export function useActiveOfficine(): ActiveOfficineContextValue {
  const ctx = useContext(Ctx);
  if (!ctx) {
    throw new Error('useActiveOfficine must be used inside <ActiveOfficineProvider>');
  }
  return ctx;
}

function readCookie(name: string): string | null {
  if (typeof document === 'undefined') return null;
  const prefix = `${name}=`;
  for (const c of document.cookie.split(';')) {
    const trimmed = c.trim();
    if (trimmed.startsWith(prefix)) return trimmed.slice(prefix.length) || null;
  }
  return null;
}
