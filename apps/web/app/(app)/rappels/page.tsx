// Page Rappels — redesign #370.
//
// Une carte par rappel : icône (forme, résolue via BDPM) + nom + statut +
// toggle actif/pause ; 4 moments (matin/midi/soir/coucher) avec quantités ;
// footer période/durée/notes + Modifier. Actions masquées pour le rôle
// Lecteur. Réutilise les mutations existantes (patch actif, delete).
'use client';

import {
  CalendarDotsIcon as CalendarDots,
  HourglassMediumIcon as HourglassMedium,
  NoteIcon as Note,
} from '@phosphor-icons/react';
import { $api, type components } from '@piloo/api-client';
import { useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';

import { MedIcon } from '@/components/app/med-icon';
import { PageHeader } from '@/components/app/page-header';
import { Panel } from '@/components/app/panel';
import { RappelFormDialog } from '@/components/app/rappels/rappel-form-dialog';
import { Button } from '@/components/ui/button';
import { useBoiteNames } from '@/lib/medoc/use-boite-names';
import { useActiveOfficine } from '@/lib/officines/active-officine';
import { useActiveOfficineName } from '@/lib/officines/use-active-officine-name';
import { cn } from '@/lib/utils';

type Rappel = components['schemas']['Rappel'];

export default function RappelsPage() {
  const { activeOfficineId } = useActiveOfficine();
  const officineName = useActiveOfficineName();

  return (
    <>
      <PageHeader eyebrow={officineName} title="Rappels" />
      {!activeOfficineId ? (
        <Panel>
          <p className="text-sm text-[var(--piloo-color-text-tertiary)]">
            Sélectionne une officine pour voir ses rappels.
          </p>
        </Panel>
      ) : (
        <RappelsList officineId={activeOfficineId} />
      )}
    </>
  );
}

function RappelsList({ officineId }: { officineId: string }) {
  const queryClient = useQueryClient();
  const { data, isLoading, error } = $api.useQuery('get', '/v1/officines/{officineId}/rappels', {
    params: { path: { officineId } },
  });
  const { data: officines } = $api.useQuery('get', '/v1/officines');
  const canWrite =
    (officines?.items.find((o) => o.id === officineId)?.role ?? 'viewer') !== 'viewer';

  const rappels = useMemo(() => data?.items ?? [], [data]);
  const cips = useMemo(() => rappels.map((r) => r.cip13), [rappels]);
  const { byCip } = useBoiteNames(cips);

  const patchMutation = $api.useMutation('patch', '/v1/rappels/{id}', {
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ['get', '/v1/officines/{officineId}/rappels'],
      });
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/prises/today'] });
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/prises'] });
    },
  });
  const deleteMutation = $api.useMutation('delete', '/v1/rappels/{id}', {
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ['get', '/v1/officines/{officineId}/rappels'],
      });
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/prises/today'] });
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/prises'] });
    },
  });

  if (isLoading) return <Muted>Chargement…</Muted>;
  if (error)
    return (
      <Panel>
        <Muted>Impossible de charger (non connecté ?).</Muted>
      </Panel>
    );
  if (rappels.length === 0)
    return (
      <Panel>
        <Muted>Aucun rappel — crée-en un depuis une boîte de ton inventaire.</Muted>
      </Panel>
    );

  const sorted = [...rappels].sort((a, b) => {
    if (a.actif !== b.actif) return a.actif ? -1 : 1;
    return a.nom_texte.localeCompare(b.nom_texte, 'fr');
  });

  return (
    <div className="flex flex-col gap-3">
      {sorted.map((r) => (
        <RappelCard
          key={r.id}
          rappel={r}
          forme={byCip.get(r.cip13)?.forme}
          canWrite={canWrite}
          busy={patchMutation.isPending || deleteMutation.isPending}
          onToggle={() => {
            patchMutation.mutate({ params: { path: { id: r.id } }, body: { actif: !r.actif } });
          }}
          onDelete={() => {
            if (window.confirm('Supprimer ce rappel ? Les prises à venir seront retirées.')) {
              deleteMutation.mutate({ params: { path: { id: r.id } } });
            }
          }}
        />
      ))}
    </div>
  );
}

const MOMENTS: {
  key: 'quantite_matin' | 'quantite_midi' | 'quantite_soir' | 'quantite_coucher';
  label: string;
}[] = [
  { key: 'quantite_matin', label: 'Matin' },
  { key: 'quantite_midi', label: 'Midi' },
  { key: 'quantite_soir', label: 'Soir' },
  { key: 'quantite_coucher', label: 'Coucher' },
];

function RappelCard({
  rappel,
  forme,
  canWrite,
  busy,
  onToggle,
  onDelete,
}: {
  rappel: Rappel;
  forme: string | null | undefined;
  canWrite: boolean;
  busy: boolean;
  onToggle: () => void;
  onDelete: () => void;
}) {
  const [editOpen, setEditOpen] = useState(false);
  return (
    <Panel className="p-[18px_20px]">
      <div className="mb-[15px] flex items-center gap-[13px]">
        <MedIcon forme={forme} size={42} />
        <span className="flex min-w-0 flex-col">
          <span className="truncate text-base font-bold tracking-[-.005em]">
            {rappel.nom_texte}
          </span>
          <span className="text-[12.5px] text-[var(--piloo-color-text-tertiary)]">
            {rappel.unite}
          </span>
        </span>
        <span className="ml-auto flex items-center gap-3">
          <span
            className={cn(
              'text-xs font-semibold',
              rappel.actif ? 'text-piloo-primary' : 'text-[var(--piloo-color-text-tertiary)]',
            )}
          >
            {rappel.actif ? 'Actif' : 'En pause'}
          </span>
          {canWrite && <Switch on={rappel.actif} disabled={busy} onClick={onToggle} />}
        </span>
      </div>

      <div className="mb-3.5 flex flex-wrap gap-2">
        {MOMENTS.map((m) => {
          const q = rappel[m.key];
          const on = q != null;
          return (
            <div
              key={m.key}
              className={cn(
                'min-w-[72px] flex-1 rounded-[11px] border px-2 py-[9px] text-center',
                on
                  ? 'border-transparent bg-piloo-primary-soft'
                  : 'border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-background',
              )}
            >
              <div
                className={cn(
                  'text-[10.5px] font-bold uppercase tracking-[.03em]',
                  on ? 'text-piloo-primary-hover' : 'text-[var(--piloo-color-text-tertiary)]',
                )}
              >
                {m.label}
              </div>
              <div
                className={cn(
                  'mt-0.5 text-base font-bold',
                  on ? 'text-piloo-primary-hover' : 'text-[var(--piloo-color-text-tertiary)]',
                )}
              >
                {on ? q : '—'}
              </div>
            </div>
          );
        })}
      </div>

      <div className="flex flex-wrap items-center gap-[18px] border-t border-[var(--piloo-color-border-soft,var(--piloo-color-border))] pt-3.5">
        <Meta Icon={CalendarDots} text={formatPeriode(rappel)} />
        <Meta Icon={HourglassMedium} text={`Durée : ${duree(rappel)}`} />
        {rappel.notes && <Meta Icon={Note} text={rappel.notes} />}
        {canWrite && (
          <div className="ml-auto flex items-center gap-1">
            <button
              type="button"
              className="text-[13px] font-semibold text-piloo-primary hover:underline"
              onClick={() => {
                setEditOpen(true);
              }}
            >
              Modifier
            </button>
            <Button
              variant="ghost"
              size="sm"
              className="text-[var(--piloo-color-text-tertiary)]"
              disabled={busy}
              onClick={onDelete}
            >
              Supprimer
            </Button>
          </div>
        )}
      </div>

      {canWrite && <RappelFormDialog rappel={rappel} open={editOpen} onOpenChange={setEditOpen} />}
    </Panel>
  );
}

function Switch({
  on,
  disabled,
  onClick,
}: {
  on: boolean;
  disabled: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={on ? 'Mettre en pause' : 'Reprendre'}
      disabled={disabled}
      onClick={onClick}
      className={cn(
        'relative h-6 w-[42px] shrink-0 rounded-full transition-colors disabled:opacity-50',
        on ? 'bg-piloo-primary' : 'bg-border',
      )}
    >
      <span
        className={cn(
          'absolute top-[3px] h-[18px] w-[18px] rounded-full bg-white shadow-[0_1px_3px_rgba(0,0,0,.22)] transition-transform',
          on ? 'translate-x-[21px]' : 'translate-x-[3px]',
        )}
      />
    </button>
  );
}

function Meta({ Icon, text }: { Icon: typeof CalendarDots; text: string }) {
  return (
    <span className="flex items-center gap-[7px] text-[12.5px] text-[var(--piloo-color-text-secondary)]">
      <Icon size={15} className="text-[var(--piloo-color-text-tertiary)]" />
      {text}
    </span>
  );
}

function Muted({ children }: { children: React.ReactNode }) {
  return <p className="text-sm text-[var(--piloo-color-text-tertiary)]">{children}</p>;
}

const FR_MONTHS = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

function formatDate(iso: string): string {
  const [y, m, d] = iso
    .slice(0, 10)
    .split('-')
    .map((n) => parseInt(n, 10));
  if (!y || !m || !d) return iso;
  const month = FR_MONTHS[m - 1] ?? '';
  return y === new Date().getFullYear()
    ? `${String(d)} ${month}`
    : `${String(d)} ${month} ${String(y)}`;
}

function formatPeriode(r: Rappel): string {
  const debut = formatDate(r.date_debut);
  return r.date_fin ? `${debut} → ${formatDate(r.date_fin)}` : `Depuis le ${debut}`;
}

function duree(r: Rappel): string {
  if (!r.date_fin) return 'à vie';
  const start = new Date(`${r.date_debut.slice(0, 10)}T00:00:00`);
  const end = new Date(`${r.date_fin.slice(0, 10)}T00:00:00`);
  const days = Math.round((end.getTime() - start.getTime()) / 86_400_000) + 1;
  return days > 0 ? `${String(days)} jour${days > 1 ? 's' : ''}` : '—';
}
