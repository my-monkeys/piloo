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
import { usePathname } from 'next/navigation';

import { useActiveOfficine } from '@/lib/officines/active-officine';
import { cn } from '@/lib/utils';

const NAV = [{ href: '/settings/officines', label: 'Officines' }];

export function Sidebar() {
  const pathname = usePathname();
  const { activeOfficineId, setActive } = useActiveOfficine();
  const { data, isLoading, error } = $api.useQuery('get', '/v1/officines');

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
        <h2 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground mb-2">
          Réglages
        </h2>
        {NAV.map((item) => {
          const active = pathname.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'block px-2 py-1.5 rounded-md text-sm transition-colors',
                active ? 'bg-piloo-primary-soft text-piloo-primary font-medium' : 'hover:bg-muted',
              )}
            >
              {item.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
