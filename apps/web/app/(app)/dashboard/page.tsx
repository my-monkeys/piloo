// Tableau de bord — redesign #370.
//
// Salutation (date + prénom) + accès rapide inventaire ; grille 2 colonnes :
// « Prochaines prises » (prises du jour, barre « oubliée » si besoin) et
// colonne droite « Alertes » (compteur) + « Stock » (3 stats). Câblé aux
// vraies données : /v1/me, /v1/prises/today, /v1/alertes, boites.
'use client';

import {
  BellRingingIcon as BellRinging,
  CalendarXIcon as CalendarX,
  HandPalmIcon as HandPalm,
  type Icon,
  PackageIcon as Package,
  PlusIcon as Plus,
  WarningIcon as Warning,
} from '@phosphor-icons/react';
import { $api, type components } from '@piloo/api-client';
import Link from 'next/link';

import { Panel, PanelHead } from '@/components/app/panel';
import { PageHeader } from '@/components/app/page-header';
import { Button } from '@/components/ui/button';
import { useActiveOfficine } from '@/lib/officines/active-officine';
import { cn } from '@/lib/utils';

type Alerte = components['schemas']['Alerte'];
type Prise = components['schemas']['PriseTimelineItem'];

export default function DashboardPage() {
  const { activeOfficineId } = useActiveOfficine();
  const { data: me } = $api.useQuery('get', '/v1/me');
  const prenom = me?.prenom;

  return (
    <>
      <PageHeader
        eyebrow={todayLabel()}
        title={prenom ? `Bonjour ${prenom}` : 'Bonjour'}
        action={
          <Button asChild variant="secondary" size="sm">
            <Link href="/inventory">
              <Plus size={17} />
              Ajouter une boîte
            </Link>
          </Button>
        }
      />

      {!activeOfficineId ? (
        <Panel>
          <p className="text-sm text-[var(--piloo-color-text-tertiary)]">
            Active une officine dans le sélecteur pour voir tes prises du jour, tes alertes et
            l&apos;état du stock.
          </p>
        </Panel>
      ) : (
        <div className="grid grid-cols-1 items-start gap-[18px] lg:grid-cols-[1.5fr_1fr]">
          <NextDosesPanel officineId={activeOfficineId} />
          <div className="flex flex-col gap-[18px]">
            <AlertsPanel />
            <StockPanel officineId={activeOfficineId} />
          </div>
        </div>
      )}
    </>
  );
}

function NextDosesPanel({ officineId }: { officineId: string }) {
  const { data, isLoading, error } = $api.useQuery('get', '/v1/prises/today', {
    params: { query: { officine_id: officineId } },
  });

  const items = data?.items ?? [];
  const oubliees = items.filter((p) => p.statut === 'oubliee');
  // Liste : oubliées + prévues, triées par heure, cap 6.
  const shown = [...items]
    .filter((p) => p.statut === 'oubliee' || p.statut === 'prevue')
    .sort((a, b) => a.datetime_prevue.localeCompare(b.datetime_prevue))
    .slice(0, 6);

  return (
    <Panel>
      <PanelHead
        title="Prochaines prises"
        aside={
          <span className="text-[12.5px] text-[var(--piloo-color-text-tertiary)]">
            aujourd&apos;hui
          </span>
        }
      />
      {isLoading && <SkeletonLines />}
      {error && <Muted>Impossible de charger (non connecté ?).</Muted>}
      {data && oubliees.length > 0 && (
        <div className="mb-1.5 flex items-center gap-[9px] rounded-[11px] bg-piloo-error px-3 py-2.5 text-[13px] font-semibold text-piloo-error-on">
          <Warning size={17} weight="fill" />
          <span>
            {oubliees.length} prise{oubliees.length > 1 ? 's' : ''} oubliée
            {oubliees.length > 1 ? 's' : ''}.
          </span>
          <Link href="/timeline" className="ml-auto font-semibold text-piloo-error-on underline">
            Régulariser
          </Link>
        </div>
      )}
      {data && shown.length === 0 && oubliees.length === 0 && (
        <Muted>Aucune prise prévue aujourd&apos;hui.</Muted>
      )}
      {shown.length > 0 && (
        <ul className="flex flex-col">
          {shown.map((p) => (
            <DoseRow key={p.id} prise={p} />
          ))}
        </ul>
      )}
    </Panel>
  );
}

function DoseRow({ prise }: { prise: Prise }) {
  const dot =
    prise.statut === 'oubliee'
      ? 'bg-piloo-error-on'
      : prise.statut === 'prise'
        ? 'bg-piloo-success-on'
        : 'bg-piloo-primary';
  const statCls =
    prise.statut === 'oubliee'
      ? 'text-piloo-error-on'
      : prise.statut === 'prise'
        ? 'text-piloo-success-on'
        : 'text-[var(--piloo-color-text-tertiary)]';
  const statLabel = { prevue: 'Prévue', prise: 'Prise', sautee: 'Sautée', oubliee: 'Oubliée' }[
    prise.statut
  ];
  return (
    <li className="flex items-center gap-[13px] border-t border-[var(--piloo-color-border-soft,var(--piloo-color-border))] px-1 py-3 first:border-t-0">
      <span className="w-11 shrink-0 text-[13px] font-semibold tabular-nums text-[var(--piloo-color-text-secondary)]">
        {formatTime(prise.datetime_prevue)}
      </span>
      <span className={cn('h-[9px] w-[9px] shrink-0 rounded-full', dot)} />
      <span className="min-w-0 flex-1 truncate text-[14.5px] font-semibold">
        {prise.prescription.nom_texte}
      </span>
      <span className={cn('text-xs font-semibold', statCls)}>{statLabel}</span>
    </li>
  );
}

const ALERTE_VISUAL: Record<Alerte['type'], { Icon: Icon; tint: string; title: string }> = {
  peremption_7j: {
    Icon: Warning,
    tint: 'bg-piloo-error text-piloo-error-on',
    title: 'Péremption imminente (< 7 j)',
  },
  peremption_30j: {
    Icon: CalendarX,
    tint: 'bg-piloo-warning text-piloo-warning-on',
    title: 'Péremption proche (< 30 j)',
  },
  stock_bas: { Icon: Package, tint: 'bg-piloo-warning text-piloo-warning-on', title: 'Stock bas' },
  prise_oubliee: {
    Icon: BellRinging,
    tint: 'bg-piloo-error text-piloo-error-on',
    title: 'Prise oubliée',
  },
  manque_signale: {
    Icon: HandPalm,
    tint: 'bg-[var(--piloo-color-info)] text-[var(--piloo-color-info-on)]',
    title: 'Manque signalé',
  },
};

function AlertsPanel() {
  const { data, isLoading, error } = $api.useQuery('get', '/v1/alertes', {
    params: { query: { unread_only: 'true', limit: 6 } },
  });
  const items = data?.items ?? [];

  return (
    <Panel>
      <PanelHead
        title="Alertes"
        aside={
          items.length > 0 ? (
            <span className="inline-flex h-5 min-w-5 items-center justify-center rounded-[10px] bg-piloo-accent-soft px-1.5 text-xs font-bold text-piloo-accent">
              {items.length}
            </span>
          ) : undefined
        }
      />
      {isLoading && <SkeletonLines />}
      {error && <Muted>Impossible de charger.</Muted>}
      {data && items.length === 0 && <Muted>Rien à signaler.</Muted>}
      {items.length > 0 && (
        <ul className="flex flex-col">
          {items.map((a) => {
            const v = ALERTE_VISUAL[a.type];
            return (
              <li
                key={a.id}
                className="flex items-start gap-[11px] border-t border-[var(--piloo-color-border-soft,var(--piloo-color-border))] px-1 py-3 first:border-t-0"
              >
                <span
                  className={cn('grid h-8 w-8 shrink-0 place-items-center rounded-[9px]', v.tint)}
                >
                  <v.Icon size={16} weight="fill" />
                </span>
                <span className="flex min-w-0 flex-col">
                  <span className="text-[13.5px] font-semibold leading-snug">{v.title}</span>
                  <span className="mt-px text-[11.5px] text-[var(--piloo-color-text-tertiary)]">
                    {formatRelative(a.created_at)}
                  </span>
                </span>
              </li>
            );
          })}
        </ul>
      )}
    </Panel>
  );
}

function StockPanel({ officineId }: { officineId: string }) {
  const { data } = $api.useQuery('get', '/v1/officines/{officineId}/boites', {
    params: { path: { officineId } },
  });
  const items = data?.items ?? [];
  const active = items.filter((b) => b.statut === 'active').length;
  const perime = items.filter((b) => b.statut === 'perimee').length;
  const vide = items.filter((b) => b.statut === 'vide').length;

  return (
    <Panel>
      <PanelHead title="Stock" />
      <div className="flex gap-2.5">
        <Stat n={active} label="Actives" />
        <Stat n={perime} label="Périmées" tone="text-piloo-error-on" />
        <Stat n={vide} label="Vides" tone="text-[var(--piloo-color-text-tertiary)]" />
      </div>
    </Panel>
  );
}

function Stat({ n, label, tone }: { n: number; label: string; tone?: string }) {
  return (
    <div className="flex flex-1 flex-col gap-[3px] rounded-xl border border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-background px-[13px] py-3.5">
      <span
        className={cn('font-display text-[30px] font-medium leading-none tracking-[-.02em]', tone)}
      >
        {n}
      </span>
      <span className="text-xs font-semibold text-[var(--piloo-color-text-tertiary)]">{label}</span>
    </div>
  );
}

function Muted({ children }: { children: React.ReactNode }) {
  return <p className="text-sm text-[var(--piloo-color-text-tertiary)]">{children}</p>;
}

function SkeletonLines() {
  return (
    <div className="flex flex-col gap-2">
      <div className="h-4 w-full animate-pulse rounded bg-piloo-surfaceSubtle" />
      <div className="h-4 w-3/4 animate-pulse rounded bg-piloo-surfaceSubtle" />
    </div>
  );
}

function todayLabel(): string {
  const s = new Date().toLocaleDateString('fr-FR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  });
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
}

function formatRelative(iso: string): string {
  const minutes = Math.round((Date.now() - new Date(iso).getTime()) / 60_000);
  if (minutes < 1) return "à l'instant";
  if (minutes < 60) return `il y a ${String(minutes)} min`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `il y a ${String(hours)} h`;
  const days = Math.round(hours / 24);
  if (days < 7) return days <= 1 ? 'hier' : `il y a ${String(days)} j`;
  return new Date(iso).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' });
}
