// Nav mobile (< md) — redesign #370. Top bar (brand + avatar officine) +
// tab bar fixe en bas. Remplace la sidebar, masquée sur mobile.
'use client';

import { PillIcon as Pill } from '@phosphor-icons/react';
import { $api } from '@piloo/api-client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

import { useActiveOfficine } from '@/lib/officines/active-officine';
import { cn } from '@/lib/utils';

import { TAB_ITEMS } from './nav-items';
import { officineAvatar } from './officine-display';

export function MobileTopBar() {
  const { activeOfficineId } = useActiveOfficine();
  const { data } = $api.useQuery('get', '/v1/officines');
  const active = data?.items.find((o) => o.id === activeOfficineId) ?? data?.items[0];
  const avatar = active ? officineAvatar(active.type) : null;

  return (
    <div className="sticky top-0 z-30 flex items-center justify-between gap-3 border-b border-border bg-[color-mix(in_srgb,var(--piloo-color-background)_90%,transparent)] px-[18px] py-3 backdrop-blur-md md:hidden">
      <Link href="/dashboard" className="flex items-center gap-[10px]">
        <span className="grid h-[30px] w-[30px] place-items-center rounded-[9px] bg-piloo-accent text-white">
          <Pill size={17} weight="fill" />
        </span>
        <span className="font-display text-[19px] font-semibold">Piloo</span>
      </Link>
      {avatar && (
        <span className={cn('grid h-[30px] w-[30px] place-items-center rounded-lg', avatar.cls)}>
          <avatar.Icon size={16} weight="fill" />
        </span>
      )}
    </div>
  );
}

export function MobileTabBar() {
  const pathname = usePathname();
  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 flex justify-around border-t border-border bg-[color-mix(in_srgb,var(--piloo-color-surface)_94%,transparent)] px-2 pb-2.5 pt-2 backdrop-blur-md md:hidden">
      {TAB_ITEMS.map((t) => {
        const active = pathname.startsWith(t.href);
        return (
          <Link
            key={t.href}
            href={t.href}
            className={cn(
              'flex flex-1 flex-col items-center gap-0.5 rounded-[10px] px-3 py-[5px] text-[10.5px] font-semibold',
              active ? 'text-piloo-primary' : 'text-[var(--piloo-color-text-tertiary)]',
            )}
          >
            <t.Icon size={22} weight={active ? 'fill' : 'regular'} />
            <span>{t.short ?? t.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
