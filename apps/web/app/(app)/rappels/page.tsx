// Page "Mes rappels" (#355). Liste les rappels de l'officine active,
// avec pause/reprise, modification et suppression.
//
// Les actions d'écriture (pause, modifier, supprimer) sont cachées pour
// le rôle viewer — l'API les refuserait de toute façon (403), mais on
// évite l'affichage d'un bouton qui ne fonctionnera pas.
'use client';

import { $api, type components } from '@piloo/api-client';
import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { RappelFormDialog } from '@/components/app/rappels/rappel-form-dialog';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { useActiveOfficine } from '@/lib/officines/active-officine';
import { cn } from '@/lib/utils';

type Rappel = components['schemas']['Rappel'];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
  // Accepte YYYY-MM-DD
  const parts = iso.slice(0, 10).split('-');
  if (parts.length !== 3) return iso;
  const day = parseInt(parts[2] ?? '0', 10);
  const month = parseInt(parts[1] ?? '0', 10) - 1;
  const year = parseInt(parts[0] ?? '0', 10);
  const currentYear = new Date().getFullYear();
  const monthName = FR_MONTHS[month] ?? '';
  return year === currentYear
    ? `${String(day)} ${monthName}`
    : `${String(day)} ${monthName} ${String(year)}`;
}

function formatPeriode(rappel: Rappel): string {
  const debut = formatDate(rappel.date_debut);
  if (rappel.date_fin) {
    return `${debut} → ${formatDate(rappel.date_fin)}`;
  }
  return `Depuis le ${debut}`;
}

function horairesSummary(r: Rappel): string {
  const p: string[] = [];
  if (r.quantite_matin != null) p.push(`Matin ${String(r.quantite_matin)}`);
  if (r.quantite_midi != null) p.push(`Midi ${String(r.quantite_midi)}`);
  if (r.quantite_soir != null) p.push(`Soir ${String(r.quantite_soir)}`);
  if (r.quantite_coucher != null) p.push(`Coucher ${String(r.quantite_coucher)}`);
  return p.join(' · ');
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

export default function RappelsPage() {
  const { activeOfficineId } = useActiveOfficine();

  return (
    <div className="space-y-6">
      <header>
        <h1 className="font-display text-3xl">Mes rappels</h1>
        <p className="text-muted-foreground">
          Posologie et planning de prises pour les médicaments de l&apos;officine active.
        </p>
      </header>

      {!activeOfficineId ? (
        <Card>
          <CardContent className="pt-6 text-sm text-muted-foreground">
            Sélectionne une officine dans la sidebar pour voir ses rappels.
          </CardContent>
        </Card>
      ) : (
        <RappelsList officineId={activeOfficineId} />
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// List component
// ---------------------------------------------------------------------------

function RappelsList({ officineId }: { officineId: string }) {
  const queryClient = useQueryClient();

  const { data, isLoading, error } = $api.useQuery(
    'get',
    '/v1/officines/{officineId}/rappels',
    { params: { path: { officineId } } },
    { enabled: !!officineId },
  );

  // Fetch officines to determine the current role on the active officine.
  const { data: officinesData } = $api.useQuery('get', '/v1/officines');
  const activeOfficine = officinesData?.items.find((o) => o.id === officineId);
  const canWrite = activeOfficine?.role !== 'viewer';

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

  if (isLoading) {
    return <p className="text-sm text-muted-foreground">Chargement…</p>;
  }

  if (error) {
    return (
      <Card>
        <CardContent className="pt-6 text-sm text-muted-foreground">
          Impossible de charger (non connecté ?).
        </CardContent>
      </Card>
    );
  }

  if (!data?.items.length) {
    return (
      <Card>
        <CardContent className="pt-6 text-sm text-muted-foreground">
          Aucun rappel — crée-en un depuis une boîte de ton inventaire.
        </CardContent>
      </Card>
    );
  }

  // Actifs en premier, puis par nom
  const sorted = [...data.items].sort((a, b) => {
    if (a.actif !== b.actif) return a.actif ? -1 : 1;
    return a.nom_texte.localeCompare(b.nom_texte, 'fr');
  });

  function handleToggleActif(rappel: Rappel) {
    patchMutation.mutate({
      params: { path: { id: rappel.id } },
      body: { actif: !rappel.actif },
    });
  }

  function handleDelete(rappel: Rappel) {
    if (window.confirm('Supprimer ce rappel ? Les prises à venir seront retirées.')) {
      deleteMutation.mutate({ params: { path: { id: rappel.id } } });
    }
  }

  return (
    <ul className="grid gap-3">
      {sorted.map((rappel) => (
        <li key={rappel.id}>
          <RappelRow
            rappel={rappel}
            canWrite={canWrite}
            onToggleActif={() => {
              handleToggleActif(rappel);
            }}
            onDelete={() => {
              handleDelete(rappel);
            }}
            isPatchPending={patchMutation.isPending}
            isDeletePending={deleteMutation.isPending}
          />
        </li>
      ))}
    </ul>
  );
}

// ---------------------------------------------------------------------------
// Row component
// ---------------------------------------------------------------------------

function RappelRow({
  rappel,
  canWrite,
  onToggleActif,
  onDelete,
  isPatchPending,
  isDeletePending,
}: {
  rappel: Rappel;
  canWrite: boolean;
  onToggleActif: () => void;
  onDelete: () => void;
  isPatchPending: boolean;
  isDeletePending: boolean;
}) {
  const [editOpen, setEditOpen] = useState(false);
  const horaires = horairesSummary(rappel);
  const periode = formatPeriode(rappel);

  return (
    <Card>
      <CardContent className="flex items-start justify-between gap-4 p-4">
        <div className="min-w-0 space-y-1">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="font-medium truncate">{rappel.nom_texte}</span>
            <span
              className={cn(
                'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium',
                rappel.actif
                  ? 'bg-piloo-success text-piloo-success-on'
                  : 'bg-muted text-muted-foreground',
              )}
            >
              {rappel.actif ? 'Actif' : 'En pause'}
            </span>
          </div>
          {horaires && (
            <p className="text-sm text-muted-foreground">
              {horaires}
              {rappel.unite ? ` ${rappel.unite}` : ''}
            </p>
          )}
          <p className="text-xs text-muted-foreground">{periode}</p>
          {rappel.notes && <p className="text-xs text-muted-foreground italic">{rappel.notes}</p>}
        </div>

        {canWrite && (
          <div className="flex items-center gap-2 shrink-0">
            <Button variant="outline" size="sm" disabled={isPatchPending} onClick={onToggleActif}>
              {rappel.actif ? 'Mettre en pause' : 'Reprendre'}
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setEditOpen(true);
              }}
            >
              Modifier
            </Button>
            <Button variant="ghost" size="sm" disabled={isDeletePending} onClick={onDelete}>
              Supprimer
            </Button>
          </div>
        )}
      </CardContent>

      {canWrite && <RappelFormDialog rappel={rappel} open={editOpen} onOpenChange={setEditOpen} />}
    </Card>
  );
}
