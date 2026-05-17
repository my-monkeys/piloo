// Sidebar de l'app shell (#73).
//
// Contenu :
// - Wordmark Piloo en haut
// - Switcher d'officine active : liste les officines accessibles
//   (via $api.useQuery('get', '/v1/officines')), highlight la courante.
// - Liens nav vers les pages settings.
//
// Quand pas authentifié : on affiche un message + lien sign-in (à
// brancher quand #169 web auth est livré).
'use client';

import { $api } from '@piloo/api-client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState } from 'react';

import { Button } from '@/components/ui/button';
import { signOut } from '@/lib/auth/client';
import { useActiveOfficine } from '@/lib/officines/active-officine';
import { cn } from '@/lib/utils';

const NAV_TOP = [{ href: '/dashboard', label: 'Tableau de bord' }];
const NAV_SETTINGS = [{ href: '/settings/officines', label: 'Officines' }];

function NavLink({ item, pathname }: { item: { href: string; label: string }; pathname: string }) {
  const active = pathname.startsWith(item.href);
  return (
    <Link
      href={item.href}
      className={cn(
        'block px-2 py-1.5 rounded-md text-sm transition-colors',
        active ? 'bg-piloo-primary-soft text-piloo-primary font-medium' : 'hover:bg-muted',
      )}
    >
      {item.label}
    </Link>
  );
}

export function Sidebar({ userName, userEmail }: { userName?: string; userEmail?: string }) {
  const pathname = usePathname();
  const router = useRouter();
  const { activeOfficineId, setActive } = useActiveOfficine();
  const { data, isLoading, error } = $api.useQuery('get', '/v1/officines');
  const [signingOut, setSigningOut] = useState(false);

  async function onSignOut() {
    setSigningOut(true);
    try {
      await signOut();
      router.push('/sign-in');
      router.refresh();
    } catch {
      setSigningOut(false);
    }
  }

  return (
    <aside className="w-64 border-r border-border bg-piloo-surface min-h-screen p-4 flex flex-col gap-6">
      <div>
        <Link href="/" className="font-display text-2xl">
          <span className="text-piloo-primary">pil</span>
          <span className="text-piloo-accent">oo</span>
        </Link>
      </div>

      <section>
        <h2 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground mb-2">
          Officine active
        </h2>
        {isLoading && <p className="text-sm text-muted-foreground">Chargement…</p>}
        {error && (
          <p className="text-sm text-muted-foreground">
            Non connecté.{' '}
            <Link href="/sign-in" className="underline">
              Se connecter
            </Link>
          </p>
        )}
        {data?.items.length === 0 && (
          <p className="text-sm text-muted-foreground">Aucune officine encore.</p>
        )}
        {data?.items.length ? (
          <ul className="space-y-1">
            {data.items.map((o) => (
              <li key={o.id}>
                <button
                  type="button"
                  onClick={() => {
                    setActive(o.id);
                  }}
                  className={cn(
                    'w-full text-left px-2 py-1.5 rounded-md text-sm transition-colors',
                    o.id === activeOfficineId
                      ? 'bg-piloo-primary-soft text-piloo-primary font-medium'
                      : 'hover:bg-muted',
                  )}
                >
                  {o.nom}
                </button>
              </li>
            ))}
          </ul>
        ) : null}
      </section>

      <nav className="space-y-1">
        {NAV_TOP.map((item) => (
          <NavLink key={item.href} item={item} pathname={pathname} />
        ))}
        <h2 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground mt-4 mb-2">
          Réglages
        </h2>
        {NAV_SETTINGS.map((item) => (
          <NavLink key={item.href} item={item} pathname={pathname} />
        ))}
      </nav>

      {(userName ?? userEmail) && (
        <div className="mt-auto pt-4 border-t border-border space-y-2">
          <div className="px-2 text-sm">
            <div className="font-medium truncate">{userName ?? 'Compte'}</div>
            {userEmail && <div className="text-xs text-muted-foreground truncate">{userEmail}</div>}
          </div>
          <Button
            variant="outline"
            size="sm"
            className="w-full"
            onClick={() => {
              void onSignOut();
            }}
            disabled={signingOut}
          >
            {signingOut ? 'Déconnexion…' : 'Se déconnecter'}
          </Button>
        </div>
      )}
    </aside>
  );
}
