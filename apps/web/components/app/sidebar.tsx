// Sidebar de l'app shell — redesign #370.
//
// Brand + switcher d'officine (dropdown) + nav principale/secondaire avec
// icônes Phosphor + user chip. Masquée < md (la nav mobile prend le relais
// via MobileTopBar + MobileTabBar). Consomme les vraies données :
// $api.useQuery('get', '/v1/officines') + useActiveOfficine.
'use client';

import {
  CaretUpDownIcon as CaretUpDown,
  CheckIcon as Check,
  SignOutIcon as SignOut,
} from '@phosphor-icons/react';
import { $api } from '@piloo/api-client';
import Image from 'next/image';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState } from 'react';

import { signOut } from '@/lib/auth/client';
import { useActiveOfficine } from '@/lib/officines/active-officine';
import { cn } from '@/lib/utils';

import { NAV_MAIN, NAV_SECONDARY, type NavItem } from './nav-items';
import { officineAvatar, roleLabel, typeLabel } from './officine-display';

function NavLink({ item, active }: { item: NavItem; active: boolean }) {
  const { Icon } = item;
  return (
    <Link
      href={item.href}
      className={cn(
        'flex items-center gap-3 rounded-[10px] px-[11px] py-[9px] text-sm font-semibold transition-colors',
        active
          ? 'bg-piloo-primary-soft text-piloo-primary-hover'
          : 'text-[var(--piloo-color-text-secondary)] hover:bg-piloo-surfaceSubtle hover:text-foreground',
      )}
    >
      <Icon
        size={19}
        weight={active ? 'fill' : 'regular'}
        className={active ? 'text-piloo-primary' : 'text-[var(--piloo-color-text-tertiary)]'}
      />
      <span>{item.label}</span>
      {item.href === '/dashboard' && (
        <span className="ml-auto h-[7px] w-[7px] rounded-full bg-piloo-accent" />
      )}
    </Link>
  );
}

function OfficineSwitcher() {
  const { activeOfficineId, setActive } = useActiveOfficine();
  const { data, isLoading } = $api.useQuery('get', '/v1/officines');
  const [open, setOpen] = useState(false);

  const officines = data?.items ?? [];
  const active = officines.find((o) => o.id === activeOfficineId) ?? officines[0];

  if (isLoading || !active) {
    return (
      <div className="flex items-center gap-[10px] rounded-xl border border-border bg-piloo-surface px-[10px] py-[9px]">
        <div className="h-[30px] w-[30px] shrink-0 animate-pulse rounded-lg bg-piloo-surfaceSubtle" />
        <div className="h-3 w-24 animate-pulse rounded bg-piloo-surfaceSubtle" />
      </div>
    );
  }

  const activeAvatar = officineAvatar(active.type);

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => {
          setOpen((v) => !v);
        }}
        className="flex w-full items-center gap-[10px] rounded-xl border border-border bg-piloo-surface px-[10px] py-[9px] text-left transition-colors hover:border-piloo-primary-soft"
      >
        <span
          className={cn(
            'grid h-[30px] w-[30px] shrink-0 place-items-center rounded-lg',
            activeAvatar.cls,
          )}
        >
          <activeAvatar.Icon size={16} weight="fill" />
        </span>
        <span className="flex min-w-0 flex-1 flex-col">
          <span className="truncate text-[13.5px] font-semibold">{active.nom}</span>
          <span className="text-[11.5px] text-[var(--piloo-color-text-tertiary)]">
            {roleLabel(active.role)}
          </span>
        </span>
        <CaretUpDown size={15} className="text-[var(--piloo-color-text-tertiary)]" />
      </button>

      {open && (
        <>
          <button
            type="button"
            aria-label="Fermer"
            className="fixed inset-0 z-10 cursor-default"
            onClick={() => {
              setOpen(false);
            }}
          />
          <div className="absolute left-0 right-0 top-[calc(100%+4px)] z-20 flex flex-col gap-0.5 rounded-xl border border-border bg-piloo-surface p-1.5 shadow-[0_12px_30px_-10px_rgba(37,42,48,.2)]">
            {officines.map((o) => {
              const av = officineAvatar(o.type);
              return (
                <button
                  key={o.id}
                  type="button"
                  onClick={() => {
                    setActive(o.id);
                    setOpen(false);
                  }}
                  className="flex items-center gap-[10px] rounded-[9px] p-2 text-left transition-colors hover:bg-piloo-surfaceSubtle"
                >
                  <span
                    className={cn(
                      'grid h-[30px] w-[30px] shrink-0 place-items-center rounded-lg',
                      av.cls,
                    )}
                  >
                    <av.Icon size={16} weight="fill" />
                  </span>
                  <span className="flex min-w-0 flex-1 flex-col">
                    <span className="truncate text-[13px] font-semibold">{o.nom}</span>
                    <span className="text-[11.5px] text-[var(--piloo-color-text-tertiary)]">
                      {typeLabel(o.type)} · {roleLabel(o.role)}
                    </span>
                  </span>
                  {o.id === active.id && <Check size={16} className="text-piloo-primary" />}
                </button>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}

export function Sidebar({ userName, userEmail }: { userName?: string; userEmail?: string }) {
  const pathname = usePathname();
  const router = useRouter();
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

  const initial = (userName ?? userEmail ?? '?').trim().charAt(0).toUpperCase();

  return (
    <aside className="sticky top-0 hidden h-screen w-[266px] shrink-0 flex-col gap-1 border-r border-border bg-piloo-background p-[22px_16px] md:flex">
      <Link href="/dashboard" className="flex items-center gap-[10px] px-2 pb-4 pt-1">
        <Image src="/logo-piloo.png" alt="" width={36} height={36} />
        <span className="font-display text-[22px] font-semibold">Piloo</span>
      </Link>

      <OfficineSwitcher />

      <nav className="mt-4 flex flex-col gap-[3px]">
        {NAV_MAIN.map((item) => (
          <NavLink key={item.href} item={item} active={pathname.startsWith(item.href)} />
        ))}
      </nav>

      <div className="mt-auto flex flex-col gap-[3px]">
        {NAV_SECONDARY.map((item) => (
          <NavLink key={item.href} item={item} active={pathname.startsWith(item.href)} />
        ))}
        {(userName ?? userEmail) && (
          <div className="mt-2 flex items-center gap-[10px] border-t border-border px-[10px] pb-1 pt-3">
            <span className="grid h-[30px] w-[30px] shrink-0 place-items-center rounded-full bg-piloo-surfaceSubtle text-[13px] font-bold">
              {initial}
            </span>
            <span className="flex min-w-0 flex-1 flex-col">
              <span className="truncate text-[13.5px] font-semibold">{userName ?? 'Compte'}</span>
              {userEmail && (
                <span className="truncate text-[11.5px] text-[var(--piloo-color-text-tertiary)]">
                  {userEmail}
                </span>
              )}
            </span>
            <button
              type="button"
              aria-label="Se déconnecter"
              onClick={() => void onSignOut()}
              disabled={signingOut}
              className="grid h-8 w-8 shrink-0 place-items-center rounded-lg text-[var(--piloo-color-text-secondary)] transition-colors hover:bg-piloo-surfaceSubtle disabled:opacity-50"
            >
              <SignOut size={17} />
            </button>
          </div>
        )}
      </div>
    </aside>
  );
}
