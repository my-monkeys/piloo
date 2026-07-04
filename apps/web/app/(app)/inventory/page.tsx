// Page inventaire — redesign name-first (#370).
//
// Le NOM du médicament est l'élément principal de chaque ligne (résolu via
// la BDPM depuis le cip13, cf. useBoiteNames) ; le CIP/lot/n° série sont
// relégués au drawer de détail. Recherche sur nom + CIP + notes, filtres
// segmentés par statut, drawer slide à droite au clic d'une ligne.
'use client';

import {
  MagnifyingGlassIcon as MagnifyingGlass,
  CaretRightIcon as CaretRight,
} from '@phosphor-icons/react';
import { $api, type components } from '@piloo/api-client';
import { useMemo, useState } from 'react';

import { Badge } from '@/components/app/badge';
import { AddBoiteDialog } from '@/components/app/inventory/add-boite-dialog';
import { BoiteDetailPanel } from '@/components/app/inventory/boite-detail-panel';
import { MedIcon } from '@/components/app/med-icon';
import { PageHeader } from '@/components/app/page-header';
import { Sheet, SheetContent } from '@/components/ui/sheet';
import {
  boiteDisplayName,
  formatPeremption,
  peremptionSeverity,
  statutBadge,
} from '@/lib/medoc/boite-display';
import { formeVisual } from '@/lib/medoc/forme';
import { useBoiteNames, type BdpmMedicament } from '@/lib/medoc/use-boite-names';
import { useActiveOfficine } from '@/lib/officines/active-officine';
import { useActiveOfficineName } from '@/lib/officines/use-active-officine-name';
import { cn } from '@/lib/utils';

type Boite = components['schemas']['Boite'];

type Filter = 'all' | 'active' | 'perime' | 'vide';
const FILTER_STATUT: Record<Exclude<Filter, 'all'>, Boite['statut']> = {
  active: 'active',
  perime: 'perimee',
  vide: 'vide',
};

interface Row {
  boite: Boite;
  med: BdpmMedicament | undefined;
  name: string;
  sev: ReturnType<typeof peremptionSeverity>;
}

export default function InventoryPage() {
  const { activeOfficineId } = useActiveOfficine();
  const officineName = useActiveOfficineName();

  return (
    <>
      <PageHeader
        eyebrow={officineName}
        title="Inventaire"
        action={activeOfficineId ? <AddBoiteDialog officineId={activeOfficineId} /> : undefined}
      />

      {!activeOfficineId ? (
        <Empty>Sélectionne une officine pour voir son inventaire.</Empty>
      ) : (
        <InventoryContent officineId={activeOfficineId} />
      )}
    </>
  );
}

function InventoryContent({ officineId }: { officineId: string }) {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<Filter>('all');
  const [opened, setOpened] = useState<Row | null>(null);
  const { data, isLoading, error } = $api.useQuery('get', '/v1/officines/{officineId}/boites', {
    params: { path: { officineId } },
  });

  const boites = useMemo(() => data?.items ?? [], [data]);
  const cips = useMemo(() => boites.map((b) => b.cip13), [boites]);
  const { byCip } = useBoiteNames(cips);

  const rows = useMemo<Row[]>(() => {
    const all = boites.map((boite) => {
      const med = byCip.get(boite.cip13);
      return {
        boite,
        med,
        name: boiteDisplayName(boite, med),
        sev: peremptionSeverity(boite.peremption),
      };
    });
    const byStatut =
      filter === 'all' ? all : all.filter((r) => r.boite.statut === FILTER_STATUT[filter]);
    const q = query.trim().toLowerCase();
    const searched = q
      ? byStatut.filter(
          (r) =>
            r.name.toLowerCase().includes(q) ||
            r.boite.cip13.includes(q) ||
            (r.boite.notes?.toLowerCase().includes(q) ?? false),
        )
      : byStatut;
    // Tri : les plus urgentes (péremption proche) d'abord.
    return [...searched].sort((a, b) => a.boite.peremption.localeCompare(b.boite.peremption));
  }, [boites, byCip, filter, query]);

  const counts = useMemo(
    () => ({
      all: boites.length,
      active: boites.filter((b) => b.statut === 'active').length,
      perime: boites.filter((b) => b.statut === 'perimee').length,
      vide: boites.filter((b) => b.statut === 'vide').length,
    }),
    [boites],
  );

  if (isLoading) return <Empty>Chargement…</Empty>;
  if (error) return <Empty>Impossible de charger l&apos;inventaire (non connecté ?).</Empty>;
  if (boites.length === 0) return <Empty>Aucune boîte enregistrée pour cette officine.</Empty>;

  return (
    <div className="flex flex-col gap-4">
      <Sheet
        open={opened !== null}
        onOpenChange={(o) => {
          if (!o) setOpened(null);
        }}
      >
        <SheetContent className="w-full overflow-y-auto p-0 sm:max-w-[460px]">
          {opened && (
            <BoiteDetailPanel
              boite={opened.boite}
              med={opened.med}
              onClose={() => {
                setOpened(null);
              }}
            />
          )}
        </SheetContent>
      </Sheet>

      <div className="flex flex-wrap items-center gap-3">
        <label className="flex min-w-[200px] flex-1 items-center gap-[9px] rounded-[11px] border border-border bg-piloo-surface px-[13px] py-[9px] transition-shadow focus-within:border-piloo-primary focus-within:shadow-[0_0_0_3px_var(--piloo-color-primary-soft)]">
          <MagnifyingGlass size={17} className="text-[var(--piloo-color-text-tertiary)]" />
          <input
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
            }}
            placeholder="Rechercher un médicament…"
            className="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-[var(--piloo-color-text-tertiary)]"
          />
        </label>
        <div className="inline-flex rounded-[11px] bg-piloo-surfaceSubtle p-[3px]">
          <FilterBtn
            label="Toutes"
            n={counts.all}
            on={filter === 'all'}
            onClick={() => {
              setFilter('all');
            }}
          />
          <FilterBtn
            label="Actives"
            n={counts.active}
            on={filter === 'active'}
            onClick={() => {
              setFilter('active');
            }}
          />
          <FilterBtn
            label="Périmées"
            n={counts.perime}
            on={filter === 'perime'}
            onClick={() => {
              setFilter('perime');
            }}
          />
          <FilterBtn
            label="Vides"
            n={counts.vide}
            on={filter === 'vide'}
            onClick={() => {
              setFilter('vide');
            }}
          />
        </div>
      </div>

      <div className="overflow-hidden rounded-2xl border border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-surface shadow-[0_1px_2px_rgba(37,42,48,.03),0_10px_26px_-18px_rgba(37,42,48,.14)]">
        <div className="hidden items-center gap-[18px] border-b border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-background px-5 py-[11px] text-[11px] font-bold uppercase tracking-[.06em] text-[var(--piloo-color-text-tertiary)] sm:flex">
          <span className="flex-[4_1_220px]">Médicament</span>
          <span className="flex-[1_1_96px]">Péremption</span>
          <span className="flex-[1_1_118px]">Stock</span>
          <span className="flex-[0_0_116px] text-right">Statut</span>
        </div>
        {rows.length === 0 ? (
          <p className="px-5 py-8 text-center text-sm text-[var(--piloo-color-text-tertiary)]">
            Aucune boîte ne correspond.
          </p>
        ) : (
          rows.map((r) => (
            <InvRow
              key={r.boite.id}
              row={r}
              onOpen={() => {
                setOpened(r);
              }}
            />
          ))
        )}
      </div>
    </div>
  );
}

function InvRow({ row, onOpen }: { row: Row; onOpen: () => void }) {
  const { boite, med, name, sev } = row;
  const forme = formeVisual(med?.forme);
  const badge = statutBadge(boite.statut);
  const rest = boite.unites_restantes ?? 0;
  const init = boite.unites_initiales ?? 0;
  const pct = init > 0 ? Math.round((rest / init) * 100) : 0;
  const low = rest <= 2;
  const secondary = [forme.label, med?.dosage].filter(Boolean).join(' · ');
  const peremColor =
    sev === 'err'
      ? 'text-piloo-error-on'
      : sev === 'warn'
        ? 'text-piloo-warning-on'
        : 'text-[var(--piloo-color-text-secondary)]';

  return (
    <button
      type="button"
      onClick={onOpen}
      className="flex w-full flex-wrap items-center gap-x-[18px] gap-y-3 border-t border-[var(--piloo-color-border-soft,var(--piloo-color-border))] px-5 py-3.5 text-left transition-colors first:border-t-0 hover:bg-piloo-surfaceSubtle sm:flex-nowrap"
    >
      <span className="flex min-w-0 flex-[4_1_220px] items-center gap-[13px]">
        <MedIcon forme={med?.forme} size={42} />
        <span className="min-w-0">
          <span className="block truncate text-[15px] font-semibold text-foreground">{name}</span>
          {secondary && (
            <span className="mt-px block truncate text-[12.5px] text-[var(--piloo-color-text-tertiary)]">
              {secondary}
            </span>
          )}
        </span>
      </span>
      <span className={cn('flex-[1_1_96px] text-[13px] font-semibold', peremColor)}>
        {formatPeremption(boite.peremption)}
      </span>
      <span className="flex flex-[1_1_118px] flex-col gap-[5px]">
        <span className="text-[13px] text-[var(--piloo-color-text-secondary)]">
          <b className="text-[14px] font-bold text-foreground">{rest}</b> / {init || '—'}
        </span>
        <span className="h-[5px] overflow-hidden rounded-[3px] bg-piloo-surfaceSubtle">
          <span
            className={cn(
              'block h-full rounded-[3px]',
              low ? 'bg-piloo-warning-on' : 'bg-piloo-primary',
            )}
            style={{ width: `${String(Math.max(pct, init > 0 ? 4 : 0))}%` }}
          />
        </span>
      </span>
      <span className="flex flex-[0_0_116px] items-center justify-end gap-3">
        <Badge tone={badge.tone}>{badge.label}</Badge>
        <CaretRight size={16} className="hidden text-[var(--piloo-color-text-tertiary)] sm:block" />
      </span>
    </button>
  );
}

function FilterBtn({
  label,
  n,
  on,
  onClick,
}: {
  label: string;
  n: number;
  on: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'inline-flex items-center gap-1.5 rounded-lg px-[13px] py-[7px] text-[13px] font-semibold transition-colors',
        on
          ? 'bg-piloo-surface text-foreground shadow-[0_1px_2px_rgba(37,42,48,.08)]'
          : 'text-[var(--piloo-color-text-secondary)] hover:text-foreground',
      )}
    >
      <span>{label}</span>
      <span
        className={cn(
          'text-[11px] font-bold',
          on ? 'text-piloo-primary' : 'text-[var(--piloo-color-text-tertiary)]',
        )}
      >
        {n}
      </span>
    </button>
  );
}

function Empty({ children }: { children: React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-surface px-5 py-8 text-sm text-[var(--piloo-color-text-tertiary)]">
      {children}
    </div>
  );
}
