'use client';

// Nav sticky de la landing (#394) : fond translucide + blur, bordure qui
// apparaît au scroll, menu burger mobile. Seul morceau client de la
// landing — tout le reste est statique.
import Link from 'next/link';
import { useEffect, useState } from 'react';

import { ListIcon as List, PillIcon as Pill, XIcon as X } from '@phosphor-icons/react';

const LINKS = [
  { href: '#atouts', label: 'Fonctionnalités' },
  { href: '/pricing', label: 'Tarifs' },
  { href: '/status', label: 'État du système' },
] as const;

const NAVLINK_CLS =
  'rounded-[9px] px-3 py-2 text-[14.5px] font-semibold text-secondary-foreground transition-colors hover:bg-piloo-surfaceSubtle hover:text-foreground';

export function LandingNav() {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => {
      setScrolled(window.scrollY > 8);
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      window.removeEventListener('scroll', onScroll);
    };
  }, []);

  const BurgerIcon = menuOpen ? X : List;

  return (
    <header
      className={`sticky top-0 z-40 border-b bg-[rgba(250,248,243,0.82)] backdrop-blur-[10px] backdrop-saturate-[1.4] transition-colors ${
        scrolled ? 'border-border' : 'border-transparent'
      }`}
    >
      <div className="mx-auto flex h-[68px] max-w-[1120px] items-center gap-4 px-[22px] sm:px-8">
        <Link href="/" className="flex items-center gap-2.5">
          <span className="grid size-[34px] place-items-center rounded-[10px] bg-piloo-accent text-white">
            <Pill size={19} weight="fill" />
          </span>
          <span className="font-display text-[22px] font-semibold tracking-tight text-foreground">
            Piloo
          </span>
        </Link>
        <nav className="ml-[22px] hidden items-center gap-1.5 md:flex">
          {LINKS.map((l) => (
            <a key={l.href} href={l.href} className={NAVLINK_CLS}>
              {l.label}
            </a>
          ))}
        </nav>
        <div className="ml-auto flex items-center gap-2">
          <Link
            href="/sign-in"
            className="hidden text-[14.5px] font-semibold text-secondary-foreground transition-colors hover:text-foreground md:inline"
          >
            Se connecter
          </Link>
          <Link
            href="/sign-up"
            className="inline-flex items-center justify-center rounded-lg bg-piloo-primary px-[17px] py-2.5 text-[14.5px] font-semibold text-white shadow-sm transition hover:-translate-y-px hover:bg-piloo-primary-hover hover:shadow-[0_8px_20px_-6px_rgba(74,107,100,0.5)]"
          >
            Créer un compte
          </Link>
          <button
            type="button"
            aria-label={menuOpen ? 'Fermer le menu' : 'Ouvrir le menu'}
            aria-expanded={menuOpen}
            onClick={() => {
              setMenuOpen((o) => !o);
            }}
            className="inline-flex size-[42px] items-center justify-center rounded-[11px] border border-border bg-piloo-surface text-foreground md:hidden"
          >
            <BurgerIcon size={22} />
          </button>
        </div>
      </div>
      {menuOpen ? (
        <div className="flex flex-col gap-1 border-t border-border px-4 pb-[18px] pt-3 md:hidden">
          {LINKS.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className={`${NAVLINK_CLS} p-3 text-base`}
              onClick={() => {
                setMenuOpen(false);
              }}
            >
              {l.label}
            </a>
          ))}
          <Link
            href="/sign-in"
            className="mt-2 inline-flex items-center justify-center rounded-lg border border-border bg-piloo-surface px-[17px] py-2.5 text-[14.5px] font-semibold text-foreground"
          >
            Se connecter
          </Link>
          <Link
            href="/sign-up"
            className="mt-2 inline-flex items-center justify-center rounded-lg bg-piloo-primary px-[17px] py-2.5 text-[14.5px] font-semibold text-white"
          >
            Créer un compte
          </Link>
        </div>
      ) : null}
    </header>
  );
}
