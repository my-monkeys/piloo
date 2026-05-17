// Page Timeline semaine (#172). Vue 7 jours × 4 moments
// (matin/midi/soir/coucher) pour visualiser le planning de prises sur
// une semaine entière, statut par prise.
//
// API : un call /v1/prises?date= par jour (7 calls). À terme on aura
// un endpoint /v1/prises?from=&to= en bulk — pour l'instant c'est OK
// (les calls sont en parallèle via TanStack Query).
'use client';

import { $api, type components } from '@piloo/api-client';
import { useState } from 'react';

import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
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

export default function TimelinePage() {
  const { activeOfficineId } = useActiveOfficine();
  const [weekStart, setWeekStart] = useState(() => startOfIsoWeek(new Date()));
  const days = isoWeekDays(weekStart);

  return (
    <div className="space-y-6">
      <header className="flex items-center justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl">Timeline</h1>
          <p className="text-muted-foreground">
            Semaine du {days[0] ? formatDayShort(days[0]) : ''}
          </p>
        </div>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              setWeekStart(addWeeks(weekStart, -1));
            }}
          >
            ←
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              setWeekStart(startOfIsoWeek(new Date()));
            }}
          >
            Aujourd&apos;hui
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              setWeekStart(addWeeks(weekStart, 1));
            }}
          >
            →
          </Button>
        </div>
      </header>

      {!activeOfficineId ? (
        <NoActiveOfficineEmpty />
      ) : (
        <WeekGrid officineId={activeOfficineId} days={days} />
      )}
    </div>
  );
}

function WeekGrid({ officineId, days }: { officineId: string; days: readonly string[] }) {
  return (
    <Card>
      <CardContent className="p-0 overflow-x-auto">
        <table className="w-full text-sm border-collapse">
          <thead>
            <tr className="border-b">
              <th className="px-3 py-2 text-left text-xs font-medium text-muted-foreground uppercase tracking-wide w-24">
                Moment
              </th>
              {days.map((d) => (
                <th
                  key={d}
                  className={cn(
                    'px-3 py-2 text-left text-xs font-medium uppercase tracking-wide',
                    isToday(d) ? 'text-piloo-primary' : 'text-muted-foreground',
                  )}
                >
                  {formatDayHeader(d)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {MOMENTS.map((m) => (
              <tr key={m} className="border-b last:border-0 align-top">
                <td className="px-3 py-3 font-medium text-foreground">{MOMENT_LABELS[m]}</td>
                {days.map((d) => (
                  <td
                    key={d}
                    className={cn('px-2 py-2 align-top min-w-32', isToday(d) && 'bg-muted/30')}
                  >
                    <DayCell officineId={officineId} date={d} moment={m} />
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </CardContent>
    </Card>
  );
}

function DayCell({
  officineId,
  date,
  moment,
}: {
  officineId: string;
  date: string;
  moment: Moment;
}) {
  const { data, isLoading } = $api.useQuery('get', '/v1/prises', {
    params: { query: { officine_id: officineId, date } },
  });

  if (isLoading) {
    return <div className="h-4 w-full bg-muted rounded animate-pulse" />;
  }
  if (!data) return null;
  const prises = data.items.filter((p) => momentForIso(p.datetime_prevue) === moment);
  if (prises.length === 0) {
    return <div className="text-xs text-muted-foreground/50">—</div>;
  }
  return (
    <ul className="space-y-1">
      {prises.map((p) => (
        <li key={p.id}>
          <PriseChip prise={p} />
        </li>
      ))}
    </ul>
  );
}

function PriseChip({ prise }: { prise: Prise }) {
  const styles: Record<Prise['statut'], string> = {
    prise: 'bg-piloo-success text-piloo-success-on',
    prevue: 'bg-piloo-primary-soft text-piloo-primary',
    sautee: 'bg-muted text-muted-foreground line-through',
    oubliee: 'bg-piloo-error text-piloo-error-on',
  };
  return (
    <div
      className={cn(
        'rounded px-2 py-1 text-xs leading-tight flex flex-col gap-0.5',
        styles[prise.statut],
      )}
      title={`${prise.prescription.nom_texte} · ${prise.statut}`}
    >
      <span className="font-medium truncate">{prise.prescription.nom_texte}</span>
      <span className="tabular-nums opacity-70">{formatTime(prise.datetime_prevue)}</span>
    </div>
  );
}

function NoActiveOfficineEmpty() {
  return (
    <Card>
      <CardContent className="pt-6 text-sm text-muted-foreground">
        Sélectionne une officine dans la sidebar pour voir sa timeline semaine.
      </CardContent>
    </Card>
  );
}

function isToday(iso: string): boolean {
  return iso === new Date().toISOString().slice(0, 10);
}

function formatDayHeader(iso: string): string {
  // "lun. 17" — compact pour les headers de colonne.
  const d = new Date(iso);
  return d.toLocaleDateString('fr-FR', { weekday: 'short', day: '2-digit' });
}

function formatDayShort(iso: string): string {
  // "17 mai 2026" — pour le sous-titre header.
  return new Date(iso).toLocaleDateString('fr-FR', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
}
