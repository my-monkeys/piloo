// Landing publique (#168, refonte #394 — maquette Claude Design
// Landing.dc.html, même système visuel que le redesign app #370).
//
// Server Component statique : pas de fetch, pas de state. Seule la nav
// (scroll + burger) est un composant client.
import Image from 'next/image';
import Link from 'next/link';

import {
  BellRingingIcon as BellRinging,
  CalendarDotsIcon as CalendarDots,
  CheckCircleIcon as CheckCircle,
  CheckIcon as Check,
  EyeSlashIcon as EyeSlash,
  FileTextIcon as FileText,
  InfoIcon as Info,
  LockSimpleIcon as LockSimple,
  MapPinIcon as MapPin,
  NotebookIcon as Notebook,
  PauseCircleIcon as PauseCircle,
  ScanIcon as Scan,
  SealCheckIcon as SealCheck,
  SquaresFourIcon as SquaresFour,
  UsersThreeIcon as UsersThree,
  WifiSlashIcon as WifiSlash,
  XCircleIcon as XCircle,
  XIcon as X,
} from '@phosphor-icons/react/dist/ssr';
import type { Icon } from '@phosphor-icons/react';

import { HeroVisual } from '@/components/landing/hero-visual';
import { LandingNav } from '@/components/landing/landing-nav';
import { PhoneMockup } from '@/components/landing/phone-mockup';
import { StoreButtons } from '@/components/landing/store-buttons';

export const dynamic = 'force-static';

const CONTAINER = 'mx-auto max-w-[1120px] px-[22px] sm:px-8';

export default function HomePage() {
  return (
    <main className="min-h-screen overflow-x-clip bg-piloo-background text-[15px]">
      <LandingNav />
      <Hero />
      <TrustStrip />
      <Features />
      <Spotlight />
      <Positioning />
      <CtaBand />
      <Footer />
    </main>
  );
}

function Hero() {
  return (
    <section className="relative pb-6 pt-11 lg:pb-[34px] lg:pt-[70px]">
      <span className="pointer-events-none absolute -top-[120px] right-[-80px] z-0 size-[460px] rounded-full bg-piloo-primary-soft opacity-55 blur-[70px]" />
      <span className="pointer-events-none absolute -bottom-[120px] left-[-120px] z-0 size-[360px] rounded-full bg-piloo-accent-soft opacity-45 blur-[70px]" />
      <div
        className={`${CONTAINER} relative z-[1] grid items-center gap-12 lg:grid-cols-[1.04fr_0.96fr] lg:gap-14`}
      >
        <div>
          <span className="mb-[22px] inline-flex max-w-full animate-rise items-center gap-2 whitespace-nowrap rounded-full border border-border bg-piloo-surface py-1.5 pl-[9px] pr-3.5 text-[13px] font-semibold text-secondary-foreground">
            <Notebook size={15} weight="fill" className="shrink-0 text-piloo-accent" />
            <span className="truncate">
              Ton carnet de médicaments,{' '}
              <b className="font-bold text-piloo-primary-hover">à la maison</b>
            </span>
          </span>
          <h1 className="m-0 mb-5 animate-rise font-display text-[40px] font-medium leading-[1.02] tracking-[-0.025em] [animation-delay:0.05s] sm:text-5xl lg:text-[60px]">
            Tes médicaments,
            <br />
            <span className="text-piloo-primary">au calme.</span>
          </h1>
          <p className="m-0 mb-[30px] max-w-[500px] animate-rise text-[17px] leading-[1.55] text-secondary-foreground [animation-delay:0.12s] lg:text-[19px]">
            Scanne tes boîtes, suis ton stock et tes dates de péremption, et partage un carnet clair
            avec tes proches. Sans stress, sans jargon.
          </p>
          <div className="animate-rise [animation-delay:0.18s]">
            <StoreButtons variant="dark" />
          </div>
          <p className="mt-[18px] flex animate-rise items-center gap-2 text-[13.5px] font-medium text-muted-foreground [animation-delay:0.24s]">
            <CheckCircle size={16} weight="fill" className="text-piloo-success-on" />
            <span>
              Gratuit pour commencer ·{' '}
              <Link href="/sign-up" className="text-piloo-primary hover:text-piloo-primary-hover">
                ou continuer dans le navigateur
              </Link>
            </span>
          </p>
        </div>
        <HeroVisual />
      </div>
    </section>
  );
}

const TRUST_ITEMS: { icon: Icon; label: string }[] = [
  { icon: SealCheck, label: 'Base officielle BDPM' },
  { icon: LockSimple, label: 'Données de santé chiffrées' },
  { icon: EyeSlash, label: 'Aucun tracker tiers' },
  { icon: MapPin, label: 'Pensé pour la France' },
];

function TrustStrip() {
  return (
    <div className="border-y border-piloo-surfaceSubtle bg-[rgba(241,237,226,0.4)]">
      <div
        className={`${CONTAINER} flex flex-wrap items-center justify-center gap-x-8 gap-y-3.5 py-5`}
      >
        {TRUST_ITEMS.map((it, i) => (
          <div key={it.label} className="contents">
            {i > 0 ? (
              <span className="hidden size-[5px] shrink-0 rounded-full bg-border sm:block" />
            ) : null}
            <span className="flex items-center gap-[9px] text-sm font-semibold text-secondary-foreground">
              <it.icon size={19} className="text-piloo-primary" />
              {it.label}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

const FEATURES: { icon: Icon; tint: 'oral' | 'inj'; title: string; text: string }[] = [
  {
    icon: Scan,
    tint: 'oral',
    title: 'Scan DataMatrix',
    text: 'Vise le code de la boîte : nom, lot et péremption se remplissent tout seuls. Zéro saisie.',
  },
  {
    icon: CalendarDots,
    tint: 'inj',
    title: 'Timeline du jour',
    text: 'Ce qui est à prendre, ce qui est fait, ce qui a été oublié. Matin, midi, soir, coucher.',
  },
  {
    icon: UsersThree,
    tint: 'oral',
    title: 'Carnet partagé',
    text: 'Partage un carnet avec tes proches, avec les bons rôles : Propriétaire, Éditeur, Lecteur.',
  },
  {
    icon: FileText,
    tint: 'inj',
    title: 'OCR ordonnance',
    text: 'Prends ton ordonnance en photo : Piloo lit la prescription et pré-remplit les traitements.',
  },
  {
    icon: WifiSlash,
    tint: 'oral',
    title: 'Marche hors-ligne',
    text: 'Consulte et mets à jour ton carnet partout. La synchro se fait au retour du réseau.',
  },
  {
    icon: SealCheck,
    tint: 'inj',
    title: 'Base BDPM officielle',
    text: 'Noms, formes et dosages viennent de la base officielle des médicaments. Des infos fiables.',
  },
];

function Features() {
  return (
    <section className="py-16 lg:py-[86px]" id="atouts">
      <div className={CONTAINER}>
        <div className="mx-auto mb-[52px] max-w-[640px] text-center">
          <p className="m-0 mb-3 text-[13px] font-bold uppercase tracking-[0.06em] text-piloo-accent">
            Ce que fait Piloo
          </p>
          <h2 className="m-0 mb-3.5 font-display text-[31px] font-medium leading-[1.1] tracking-[-0.02em] md:text-[40px]">
            Tout ce qu’il faut, rien de trop.
          </h2>
          <p className="m-0 text-[17px] leading-[1.55] text-secondary-foreground">
            De la boîte scannée à la prise du soir, Piloo garde ton armoire à pharmacie claire et à
            jour.
          </p>
        </div>
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f) => (
            <article
              key={f.title}
              className="rounded-[18px] border border-piloo-surfaceSubtle bg-piloo-surface p-[26px] shadow-[0_1px_2px_rgba(37,42,48,0.03)] transition duration-200 hover:-translate-y-[3px] hover:border-border hover:shadow-[0_18px_40px_-22px_rgba(37,42,48,0.3)]"
            >
              <span
                className={`mb-[18px] grid size-[52px] place-items-center rounded-[14px] ${
                  f.tint === 'oral'
                    ? 'bg-piloo-primary-soft text-piloo-primary-hover'
                    : 'bg-piloo-accent-soft text-piloo-accent'
                }`}
              >
                <f.icon size={27} />
              </span>
              <h3 className="m-0 mb-2 text-lg font-bold tracking-tight">{f.title}</h3>
              <p className="m-0 text-[14.5px] leading-[1.55] text-secondary-foreground">{f.text}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

const SPOT_FEATS: { icon: Icon; title: string; text: string }[] = [
  {
    icon: SquaresFour,
    title: 'Organisé par moment',
    text: 'Matin, midi, soir, coucher — chaque prise à sa place, comme un vrai pilulier.',
  },
  {
    icon: BellRinging,
    title: 'Rappels à l’heure',
    text: 'Une notification douce au bon moment. Tu coches, et c’est réglé.',
  },
  {
    icon: PauseCircle,
    title: 'Pause & reprise',
    text: 'Traitement terminé ou en pause ? Suspends un rappel sans le supprimer.',
  },
];

function Spotlight() {
  return (
    <section className="border-y border-piloo-surfaceSubtle bg-[rgba(241,237,226,0.5)] py-16 lg:py-[88px]">
      <div
        className={`${CONTAINER} grid items-center justify-items-center gap-11 lg:grid-cols-[0.92fr_1.08fr] lg:gap-[60px]`}
      >
        <PhoneMockup />
        <div className="mx-auto max-w-[520px] text-center lg:mx-0 lg:max-w-none lg:text-left">
          <p className="m-0 mb-3 text-[13px] font-bold uppercase tracking-[0.06em] text-piloo-accent">
            Comme un pilulier, en mieux
          </p>
          <h2 className="m-0 mb-3.5 font-display text-[31px] font-medium leading-[1.1] tracking-[-0.02em] md:text-[40px]">
            Tes prises, déjà rangées.
          </h2>
          <p className="m-0 text-[17px] leading-[1.55] text-secondary-foreground">
            Piloo range tes médicaments par moment de la journée et te rappelle chaque prise. Fini
            les petites cases en plastique à remplir le dimanche soir.
          </p>
          <div className="mt-7 flex flex-col gap-[18px] text-left">
            {SPOT_FEATS.map((f) => (
              <div key={f.title} className="flex gap-3.5">
                <span className="grid size-11 shrink-0 place-items-center rounded-[13px] bg-piloo-primary-soft text-piloo-primary-hover">
                  <f.icon size={22} />
                </span>
                <div>
                  <div className="text-[15.5px] font-bold tracking-tight">{f.title}</div>
                  <div className="mt-[3px] text-sm leading-normal text-secondary-foreground">
                    {f.text}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

const NOT_LIST = [
  'Un dispositif médical',
  'Un validateur d’ordonnance',
  'Un remplaçant de ton médecin ou pharmacien',
];

const IS_LIST = [
  'Un aide-mémoire personnel',
  'Un carnet partagé avec tes proches',
  'Un rappel clair de tes prises',
];

function Positioning() {
  return (
    <section className="pb-16 pt-2 lg:pb-[86px] lg:pt-5">
      <div className={CONTAINER}>
        <div className="grid overflow-hidden rounded-3xl border border-piloo-surfaceSubtle bg-piloo-surface shadow-[0_2px_4px_rgba(37,42,48,0.03),0_24px_50px_-30px_rgba(37,42,48,0.22)] md:grid-cols-2">
          <div className="border-b border-piloo-surfaceSubtle p-7 md:border-b-0 md:border-r md:p-[44px_46px]">
            <p className="m-0 mb-[22px] inline-flex items-center gap-[9px] text-[13px] font-bold uppercase tracking-[0.04em] text-piloo-error-on">
              <XCircle size={16} weight="fill" />
              Ce que Piloo n’est pas
            </p>
            <ul className="m-0 flex list-none flex-col gap-4 p-0">
              {NOT_LIST.map((n) => (
                <li key={n} className="flex items-start gap-[13px] text-base font-semibold">
                  <span className="mt-px grid size-[26px] shrink-0 place-items-center rounded-lg bg-piloo-error text-piloo-error-on">
                    <X size={16} />
                  </span>
                  <span className="text-secondary-foreground">{n}</span>
                </li>
              ))}
            </ul>
            <p className="m-0 mt-[30px] text-[14.5px] leading-[1.6] text-secondary-foreground">
              Pour toute question de santé,{' '}
              <b className="font-bold text-foreground">ton médecin et ton pharmacien</b> restent tes
              interlocuteurs. Piloo ne les remplace pas.
            </p>
          </div>
          <div className="bg-[rgba(219,227,224,0.28)] p-7 md:p-[44px_46px]">
            <p className="m-0 mb-[22px] inline-flex items-center gap-[9px] text-[13px] font-bold uppercase tracking-[0.04em] text-piloo-success-on">
              <CheckCircle size={16} weight="fill" />
              Ce que Piloo est
            </p>
            <ul className="m-0 flex list-none flex-col gap-4 p-0">
              {IS_LIST.map((n) => (
                <li key={n} className="flex items-start gap-[13px] text-base font-semibold">
                  <span className="mt-px grid size-[26px] shrink-0 place-items-center rounded-lg bg-piloo-success text-piloo-success-on">
                    <Check size={16} />
                  </span>
                  <span>{n}</span>
                </li>
              ))}
            </ul>
            <p className="m-0 mt-[30px] text-[14.5px] leading-[1.6] text-secondary-foreground">
              Un <b className="font-bold text-foreground">aide-mémoire personnel</b>, calme et
              rassurant. Rien de plus, et c’est déjà beaucoup.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}

function CtaBand() {
  return (
    <section className="pb-16 lg:pb-[86px]">
      <div className={CONTAINER}>
        <div className="relative overflow-hidden rounded-[28px] bg-piloo-primary px-[26px] py-[52px] text-center shadow-[0_30px_60px_-30px_rgba(74,107,100,0.6)] lg:px-10 lg:py-[70px]">
          <span className="absolute -top-[140px] left-[-60px] size-[320px] rounded-full bg-[#6d8b84] opacity-35 blur-[60px]" />
          <span className="absolute -bottom-[140px] right-[-40px] size-[280px] rounded-full bg-piloo-accent opacity-20 blur-[60px]" />
          <h2 className="relative z-[1] mx-auto mb-3.5 max-w-[620px] font-display text-[31px] font-medium leading-[1.08] tracking-[-0.02em] text-white lg:text-[42px]">
            Prêt à ranger tes médicaments, au calme ?
          </h2>
          <p className="relative z-[1] mx-auto mb-[30px] max-w-[480px] text-[17px] text-white/80">
            Crée ton carnet en deux minutes. Scanne ta première boîte ce soir.
          </p>
          <div className="relative z-[1]">
            <StoreButtons variant="light" align="center" />
          </div>
          <p className="relative z-[1] mt-4 text-[13.5px] font-medium text-white/70">
            Gratuit · Famille à 4,99 €/mois ·{' '}
            <Link href="/sign-up" className="text-white underline hover:text-white">
              ou crée ton carnet dans le navigateur
            </Link>
          </p>
        </div>
      </div>
    </section>
  );
}

const FOOTER_COLS: { title: string; links: { href: string; label: string }[] }[] = [
  {
    title: 'Produit',
    links: [
      { href: '#atouts', label: 'Fonctionnalités' },
      { href: '/pricing', label: 'Tarifs' },
      { href: '/status', label: 'État du système' },
    ],
  },
  {
    title: 'Compte',
    links: [
      { href: '/sign-in', label: 'Se connecter' },
      { href: '/sign-up', label: 'Créer un compte' },
    ],
  },
  {
    title: 'Légal',
    links: [
      { href: '/legal/cgu', label: 'CGU' },
      { href: '/legal/privacy', label: 'Confidentialité' },
      { href: '/legal/mentions', label: 'Mentions légales' },
      { href: '/legal/cookies', label: 'Cookies' },
    ],
  },
];

function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="border-t border-border pb-[34px] pt-[60px]">
      <div className={CONTAINER}>
        <div className="mb-11 grid grid-cols-2 gap-7 md:grid-cols-[1.6fr_1fr_1fr_1fr] md:gap-9">
          <div className="col-span-2 md:col-span-1">
            <Link href="/" className="flex items-center gap-2.5">
              <Image src="/logo-piloo.png" alt="" width={36} height={36} />
              <span className="font-display text-[22px] font-semibold tracking-tight text-foreground">
                Piloo
              </span>
            </Link>
            <p className="m-0 mt-4 max-w-[280px] text-[14.5px] leading-[1.55] text-secondary-foreground">
              Le carnet numérique de médicaments pour la maison. Tes médicaments, au calme.
            </p>
          </div>
          {FOOTER_COLS.map((col) => (
            <div key={col.title}>
              <h4 className="m-0 mb-4 text-xs font-bold uppercase tracking-[0.06em] text-muted-foreground">
                {col.title}
              </h4>
              <ul className="m-0 flex list-none flex-col gap-[11px] p-0">
                {col.links.map((l) => (
                  <li key={l.href}>
                    <a
                      href={l.href}
                      className="text-[14.5px] font-semibold text-secondary-foreground transition-colors hover:text-foreground"
                    >
                      {l.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="flex flex-wrap items-center justify-between gap-4 border-t border-piloo-surfaceSubtle pt-[26px]">
          <span className="flex items-center gap-[9px] text-[13px] font-semibold text-muted-foreground">
            <Info size={16} />
            Piloo n’est pas un dispositif médical.
          </span>
          <span className="text-[13px] text-muted-foreground">
            © {year} Piloo · Fait avec soin en France
          </span>
        </div>
      </div>
    </footer>
  );
}
