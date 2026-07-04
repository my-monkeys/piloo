// Page Timeline — redesign #370.
//
// Grille semaine 7 jours × 4 moments (matin/midi/soir/coucher). Chaque prise
// est une chip colorée par statut. Clic → modale (marquer prise/sautée/reset).
// Mobile : onglets jours + liste des moments. Données : un call /v1/prises?date=
// par jour (dédupliqué par TanStack Query entre les cellules d'un même jour).
'use client';

import {
  CalendarBlankIcon as CalendarBlank,
  CaretLeftIcon as CaretLeft,
  CaretRightIcon as CaretRight,
  CloudMoonIcon as CloudMoon,
  type Icon,
  MoonStarsIcon as MoonStars,
  SunHorizonIcon as SunHorizon,
  SunIcon as Sun,
} from '@phosphor-icons/react';
import { $api, type components } from '@piloo/api-client';
import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { Panel } from '@/components/app/panel';
import { PageHeader } from '@/components/app/page-header';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import {
  addWeeks,
  isoWeekDays,
  MOMENT_LABELS,
  MOMENTS,
  momentForIso,
  startOfIsoWeek,
  type Moment,
} from '@/lib/timeline/utils';
import { useActiveOfficine } from '@/lib/officines/active-officine';
import { cn } from '@/lib/utils';

type Prise = components['schemas']['PriseTimelineItem'];

const MOMENT_META: Record<Moment, { Icon: Icon; time: string }> = {
  matin: { Icon: SunHorizon, time: '08:00' },
  midi: { Icon: Sun, time: '12:00' },
  soir: { Icon: CloudMoon, time: '19:00' },
  coucher: { Icon: MoonStars, time: '21:00' },
};

const CHIP_STYLES: Record<Prise['statut'], string> = {
  prise: 'bg-piloo-success text-piloo-success-on',
  prevue: 'bg-piloo-background border border-border text-[var(--piloo-color-text-secondary)]',
  sautee:
    'bg-piloo-surfaceSubtle text-[var(--piloo-color-text-tertiary)] [&_.chipname]:line-through',
  oubliee: 'bg-piloo-error text-piloo-error-on',
};

export default function TimelinePage() {
  const { activeOfficineId } = useActiveOfficine();
  const [weekStart, setWeekStart] = useState(() => startOfIsoWeek(new Date()));
  const [opened, setOpened] = useState<Prise | null>(null);
  const [mobileDay, setMobileDay] = useState(() => todayIndex(startOfIsoWeek(new Date())));
  const days = isoWeekDays(weekStart);

  return (
    <>
      <PageHeader
        eyebrow={days[0] && days[6] ? `Semaine du ${formatRange(days[0], days[6])}` : undefined}
        title="Timeline"
        action={
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setWeekStart(addWeeks(weekStart, -1));
              }}
              aria-label="Semaine précédente"
            >
              <CaretLeft size={16} />
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setWeekStart(startOfIsoWeek(new Date()));
                setMobileDay(todayIndex(startOfIsoWeek(new Date())));
              }}
            >
              <CalendarBlank size={16} />
              Cette semaine
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setWeekStart(addWeeks(weekStart, 1));
              }}
              aria-label="Semaine suivante"
            >
              <CaretRight size={16} />
            </Button>
          </div>
        }
      />

      {!activeOfficineId ? (
        <Panel>
          <p className="text-sm text-[var(--piloo-color-text-tertiary)]">
            Sélectionne une officine pour voir sa timeline.
          </p>
        </Panel>
      ) : (
        <>
          <WeekGrid officineId={activeOfficineId} days={days} onSelect={setOpened} />
          <Legend />
          <MobileWeek
            officineId={activeOfficineId}
            days={days}
            selected={mobileDay}
            onSelectDay={setMobileDay}
            onSelect={setOpened}
          />
        </>
      )}

      <PriseDialog
        prise={opened}
        onClose={() => {
          setOpened(null);
        }}
      />
    </>
  );
}

function WeekGrid({
  officineId,
  days,
  onSelect,
}: {
  officineId: string;
  days: readonly string[];
  onSelect: (p: Prise) => void;
}) {
  return (
    <div
      className="hidden overflow-hidden rounded-2xl border border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-surface shadow-[0_1px_2px_rgba(37,42,48,.03),0_10px_26px_-18px_rgba(37,42,48,.14)] md:grid"
      style={{ gridTemplateColumns: '96px repeat(7, minmax(0, 1fr))' }}
    >
      <div className="border-b border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-background" />
      {days.map((d) => (
        <div
          key={d}
          className={cn(
            'border-b border-l border-[var(--piloo-color-border-soft,var(--piloo-color-border))] px-1.5 py-3 text-center',
            isToday(d) ? 'bg-piloo-primary-soft' : 'bg-piloo-background',
          )}
        >
          <span
            className={cn(
              'block text-[11.5px] font-semibold uppercase tracking-[.04em]',
              isToday(d) ? 'text-piloo-primary-hover' : 'text-[var(--piloo-color-text-tertiary)]',
            )}
          >
            {dayAbbr(d)}
          </span>
          <span
            className={cn(
              'mt-px block font-display text-[17px] font-semibold',
              isToday(d) ? 'text-piloo-primary-hover' : 'text-foreground',
            )}
          >
            {dayNum(d)}
          </span>
        </div>
      ))}
      {MOMENTS.map((m) => {
        const meta = MOMENT_META[m];
        return (
          <MomentRow key={m}>
            <div className="flex flex-col justify-center gap-[3px] border-t border-[var(--piloo-color-border-soft,var(--piloo-color-border))] px-3 py-3.5">
              <meta.Icon size={18} className="text-[var(--piloo-color-text-tertiary)]" />
              <span className="text-[13px] font-bold">{MOMENT_LABELS[m]}</span>
              <span className="text-[11.5px] tabular-nums text-[var(--piloo-color-text-tertiary)]">
                {meta.time}
              </span>
            </div>
            {days.map((d) => (
              <Cell
                key={d}
                officineId={officineId}
                date={d}
                moment={m}
                onSelect={onSelect}
                today={isToday(d)}
              />
            ))}
          </MomentRow>
        );
      })}
    </div>
  );
}

// Fragment transparent : les enfants (moment-header + 7 cellules) se placent
// directement dans la grille parente.
function MomentRow({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

function Cell({
  officineId,
  date,
  moment,
  onSelect,
  today,
}: {
  officineId: string;
  date: string;
  moment: Moment;
  onSelect: (p: Prise) => void;
  today: boolean;
}) {
  const { data } = $api.useQuery('get', '/v1/prises', {
    params: { query: { officine_id: officineId, date } },
  });
  const prises = (data?.items ?? []).filter((p) => momentForIso(p.datetime_prevue) === moment);
  return (
    <div
      className={cn(
        'flex min-h-[66px] flex-col gap-1.5 border-l border-t border-[var(--piloo-color-border-soft,var(--piloo-color-border))] p-2',
        today && 'bg-[rgba(219,227,224,.26)]',
      )}
    >
      {prises.map((p) => (
        <Chip
          key={p.id}
          prise={p}
          onClick={() => {
            onSelect(p);
          }}
        />
      ))}
    </div>
  );
}

function Chip({ prise, onClick, full }: { prise: Prise; onClick: () => void; full?: boolean }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'block w-full rounded-[9px] px-2.5 py-1.5 text-left transition-transform hover:-translate-y-px',
        CHIP_STYLES[prise.statut],
      )}
    >
      <span
        className={cn(
          'chipname block text-[12px] font-semibold leading-tight',
          !full && 'truncate',
        )}
      >
        {prise.prescription.nom_texte}
      </span>
      <span className="mt-px block text-[10.5px] font-semibold tabular-nums opacity-80">
        {formatTime(prise.datetime_prevue)}
      </span>
    </button>
  );
}

function Legend() {
  const items: { cls: string; label: string }[] = [
    { cls: 'bg-piloo-success', label: 'Prise' },
    { cls: 'bg-piloo-background border border-border', label: 'Prévue' },
    { cls: 'bg-piloo-surfaceSubtle', label: 'Sautée' },
    { cls: 'bg-piloo-error', label: 'Oubliée' },
  ];
  return (
    <div className="mt-3.5 hidden flex-wrap gap-4 px-0.5 md:flex">
      {items.map((i) => (
        <span
          key={i.label}
          className="flex items-center gap-[7px] text-xs font-semibold text-[var(--piloo-color-text-secondary)]"
        >
          <span className={cn('h-3 w-3 shrink-0 rounded', i.cls)} />
          {i.label}
        </span>
      ))}
    </div>
  );
}

function MobileWeek({
  officineId,
  days,
  selected,
  onSelectDay,
  onSelect,
}: {
  officineId: string;
  days: readonly string[];
  selected: number;
  onSelectDay: (i: number) => void;
  onSelect: (p: Prise) => void;
}) {
  const day = days[Math.min(selected, days.length - 1)] ?? days[0];
  if (!day) return null;
  return (
    <div className="md:hidden">
      <div className="mb-3.5 flex gap-1.5 overflow-x-auto pb-1.5">
        {days.map((d, i) => (
          <button
            key={d}
            type="button"
            onClick={() => {
              onSelectDay(i);
            }}
            className={cn(
              'flex min-w-[54px] shrink-0 flex-col items-center rounded-xl border px-3 py-2',
              i === selected
                ? 'border-piloo-primary bg-piloo-primary'
                : 'border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-surface',
            )}
          >
            <span
              className={cn(
                'text-[11px] font-semibold uppercase',
                i === selected ? 'text-white/80' : 'text-[var(--piloo-color-text-tertiary)]',
              )}
            >
              {dayAbbr(d)}
            </span>
            <span
              className={cn(
                'text-base font-bold',
                i === selected ? 'text-white' : 'text-foreground',
              )}
            >
              {dayNum(d)}
            </span>
          </button>
        ))}
      </div>
      <div className="flex flex-col gap-2.5">
        {MOMENTS.map((m) => (
          <MobileMoment key={m} officineId={officineId} date={day} moment={m} onSelect={onSelect} />
        ))}
      </div>
    </div>
  );
}

function MobileMoment({
  officineId,
  date,
  moment,
  onSelect,
}: {
  officineId: string;
  date: string;
  moment: Moment;
  onSelect: (p: Prise) => void;
}) {
  const { data } = $api.useQuery('get', '/v1/prises', {
    params: { query: { officine_id: officineId, date } },
  });
  const meta = MOMENT_META[moment];
  const prises = (data?.items ?? []).filter((p) => momentForIso(p.datetime_prevue) === moment);
  return (
    <Panel className="p-3.5">
      <div className="mb-2.5 flex items-center gap-2">
        <meta.Icon size={17} className="text-[var(--piloo-color-text-tertiary)]" />
        <span className="text-[13px] font-bold">{MOMENT_LABELS[moment]}</span>
        <span className="ml-auto text-[11.5px] tabular-nums text-[var(--piloo-color-text-tertiary)]">
          {meta.time}
        </span>
      </div>
      <div className="flex flex-col gap-[7px]">
        {prises.length === 0 ? (
          <span className="text-[12.5px] italic text-[var(--piloo-color-text-tertiary)]">
            Aucune prise prévue.
          </span>
        ) : (
          prises.map((p) => (
            <Chip
              key={p.id}
              prise={p}
              full
              onClick={() => {
                onSelect(p);
              }}
            />
          ))
        )}
      </div>
    </Panel>
  );
}

const STATUT_LABEL: Record<Prise['statut'], string> = {
  prise: 'Prise',
  prevue: 'Prévue',
  sautee: 'Sautée',
  oubliee: 'Oubliée',
};

function PriseDialog({ prise, onClose }: { prise: Prise | null; onClose: () => void }) {
  const queryClient = useQueryClient();
  const mutation = $api.useMutation('patch', '/v1/prises/{id}', {
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/prises'] });
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/prises/today'] });
      onClose();
    },
  });
  const setStatut = (statut: 'prise' | 'sautee' | 'prevue') => {
    if (!prise) return;
    mutation.mutate({ params: { path: { id: prise.id } }, body: { statut } });
  };

  return (
    <Dialog
      open={prise !== null}
      onOpenChange={(o) => {
        if (!o) {
          mutation.reset();
          onClose();
        }
      }}
    >
      <DialogContent className="max-w-[400px]">
        {prise && (
          <div className="flex flex-col gap-5">
            <div>
              <h2 className="text-lg font-bold tracking-[-.005em]">
                {prise.prescription.nom_texte}
              </h2>
              <p className="text-[12.5px] text-[var(--piloo-color-text-tertiary)]">
                Prévue à {formatTime(prise.datetime_prevue)}
              </p>
            </div>
            <dl className="flex flex-col gap-3 border-y border-[var(--piloo-color-border-soft,var(--piloo-color-border))] py-4">
              <Kv k="Heure prévue" v={formatTime(prise.datetime_prevue)} />
              <Kv k="Statut" v={STATUT_LABEL[prise.statut]} />
              {prise.prescription.indication && (
                <Kv k="Indication" v={prise.prescription.indication} />
              )}
            </dl>
            <div className="flex flex-wrap gap-2">
              <Button
                disabled={prise.statut === 'prise' || mutation.isPending}
                onClick={() => {
                  setStatut('prise');
                }}
              >
                Marquer prise
              </Button>
              <Button
                variant="outline"
                disabled={prise.statut === 'sautee' || mutation.isPending}
                onClick={() => {
                  setStatut('sautee');
                }}
              >
                Sautée
              </Button>
              {prise.statut !== 'prevue' && (
                <Button
                  variant="ghost"
                  disabled={mutation.isPending}
                  onClick={() => {
                    setStatut('prevue');
                  }}
                >
                  Réinitialiser
                </Button>
              )}
            </div>
            {mutation.error && (
              <p className="text-sm text-piloo-error-on">Impossible de mettre à jour. Réessaie.</p>
            )}
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}

function Kv({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4">
      <span className="text-[13px] text-[var(--piloo-color-text-secondary)]">{k}</span>
      <span className="text-[13.5px] font-semibold">{v}</span>
    </div>
  );
}

function isToday(iso: string): boolean {
  return iso === localIsoDate(new Date());
}

function todayIndex(weekStart: Date): number {
  const days = isoWeekDays(weekStart);
  const today = localIsoDate(new Date());
  const i = days.indexOf(today);
  return i >= 0 ? i : 0;
}

function localIsoDate(d: Date): string {
  return `${String(d.getFullYear())}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function dayAbbr(iso: string): string {
  return new Date(`${iso}T00:00:00`)
    .toLocaleDateString('fr-FR', { weekday: 'short' })
    .replace('.', '');
}

function dayNum(iso: string): string {
  return String(new Date(`${iso}T00:00:00`).getDate());
}

function formatRange(from: string, to: string): string {
  const f = new Date(`${from}T00:00:00`);
  const t = new Date(`${to}T00:00:00`);
  const fmt = (d: Date, withMonth: boolean) =>
    d.toLocaleDateString(
      'fr-FR',
      withMonth ? { day: 'numeric', month: 'long' } : { day: 'numeric' },
    );
  return `${fmt(f, f.getMonth() !== t.getMonth())} — ${fmt(t, true)}`;
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
}
