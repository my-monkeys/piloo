// Contenu du panneau slide (shadcn Sheet) pour une boîte sélectionnée.
//
// Lecture seule au départ (cf. #171). Cette PR ajoute les actions :
//   - Ajuster stock (PATCH unites_restantes)
//   - Marquer vide (PATCH statut=vide, stock=0)
//   - Marquer périmée (PATCH statut=perimee)
//   - Supprimer (DELETE soft)
//
// Toutes les destructives passent par une confirmation inline (pas de
// modal imbriquée — UX simple et claire dans le contexte du Sheet).
'use client';

import { $api, type components } from '@piloo/api-client';
import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { cn } from '@/lib/utils';

type Boite = components['schemas']['Boite'];

interface Props {
  boite: Boite;
  onClose: () => void;
}

export function BoiteDetailPanel({ boite, onClose }: Props) {
  return (
    <div className="space-y-6">
      <BoiteInfo boite={boite} />
      <BoiteActions boite={boite} onDone={onClose} />
    </div>
  );
}

function BoiteInfo({ boite }: { boite: Boite }) {
  return (
    <dl className="mt-6 space-y-3 text-sm">
      <Row label="CIP13" value={<span className="font-mono">{boite.cip13}</span>} />
      <Row label="Lot" value={boite.lot ?? '—'} />
      <Row label="N° série" value={boite.numero_serie ?? '—'} />
      <Row label="Péremption" value={formatDate(boite.peremption)} />
      <Row
        label="Stock"
        value={
          boite.unites_restantes !== null && boite.unites_initiales !== null
            ? `${String(boite.unites_restantes)} / ${String(boite.unites_initiales)} unités`
            : (boite.unites_restantes?.toString() ?? '—')
        }
      />
      <Row label="Statut" value={<StatutBadge statut={boite.statut} />} />
      <Row label="Ajoutée le" value={formatDate(boite.created_at)} />
      {boite.notes && <Row label="Notes" value={boite.notes} />}
    </dl>
  );
}

type ConfirmAction = 'vide' | 'perimee' | 'delete' | null;

function BoiteActions({ boite, onDone }: { boite: Boite; onDone: () => void }) {
  const queryClient = useQueryClient();
  const [confirming, setConfirming] = useState<ConfirmAction>(null);
  const [stockDraft, setStockDraft] = useState<string>(
    boite.unites_restantes !== null ? String(boite.unites_restantes) : '',
  );

  function refresh() {
    void queryClient.invalidateQueries({
      queryKey: ['get', '/v1/officines/{officineId}/boites'],
    });
  }

  const patchMutation = $api.useMutation('patch', '/v1/boites/{id}', {
    onSuccess: () => {
      refresh();
      onDone();
    },
  });

  const deleteMutation = $api.useMutation('delete', '/v1/boites/{id}', {
    onSuccess: () => {
      refresh();
      onDone();
    },
  });

  function patch(body: components['schemas']['UpdateBoiteInput']) {
    patchMutation.mutate({ params: { path: { id: boite.id } }, body });
  }

  const isBusy = patchMutation.isPending || deleteMutation.isPending;
  const stockNum = Number(stockDraft);
  const canSaveStock =
    stockDraft.trim() !== '' &&
    Number.isInteger(stockNum) &&
    stockNum >= 0 &&
    stockNum !== boite.unites_restantes &&
    !isBusy;

  return (
    <div className="space-y-4 border-t pt-4">
      <h3 className="text-sm font-medium uppercase tracking-wide text-muted-foreground">Actions</h3>

      <div className="space-y-2">
        <Label htmlFor="stock-adjust">Ajuster le stock</Label>
        <div className="flex items-center gap-2">
          <Input
            id="stock-adjust"
            type="number"
            min={0}
            inputMode="numeric"
            value={stockDraft}
            onChange={(e) => {
              setStockDraft(e.target.value);
            }}
            className="max-w-[140px]"
          />
          <Button
            type="button"
            variant="secondary"
            size="sm"
            disabled={!canSaveStock}
            onClick={() => {
              patch({ unites_restantes: stockNum });
            }}
          >
            Enregistrer
          </Button>
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        {boite.statut !== 'vide' && (
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={isBusy}
            onClick={() => {
              setConfirming('vide');
            }}
          >
            Marquer vide
          </Button>
        )}
        {boite.statut !== 'perimee' && (
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={isBusy}
            onClick={() => {
              setConfirming('perimee');
            }}
          >
            Marquer périmée
          </Button>
        )}
        <Button
          type="button"
          variant="destructive"
          size="sm"
          disabled={isBusy}
          onClick={() => {
            setConfirming('delete');
          }}
        >
          Supprimer
        </Button>
      </div>

      {confirming === 'vide' && (
        <ConfirmBar
          message="Marquer cette boîte comme vide ? Stock mis à 0."
          confirmLabel="Marquer vide"
          onCancel={() => {
            setConfirming(null);
          }}
          onConfirm={() => {
            patch({ statut: 'vide', unites_restantes: 0 });
          }}
          pending={patchMutation.isPending}
        />
      )}
      {confirming === 'perimee' && (
        <ConfirmBar
          message="Marquer cette boîte comme périmée ? Elle ne sera plus comptée comme disponible."
          confirmLabel="Marquer périmée"
          onCancel={() => {
            setConfirming(null);
          }}
          onConfirm={() => {
            patch({ statut: 'perimee' });
          }}
          pending={patchMutation.isPending}
        />
      )}
      {confirming === 'delete' && (
        <ConfirmBar
          message="Supprimer définitivement cette boîte de l'inventaire ?"
          confirmLabel="Supprimer"
          onCancel={() => {
            setConfirming(null);
          }}
          onConfirm={() => {
            deleteMutation.mutate({ params: { path: { id: boite.id } } });
          }}
          pending={deleteMutation.isPending}
          destructive
        />
      )}

      {(patchMutation.error ?? deleteMutation.error) && (
        <p className="text-sm text-destructive">
          L&apos;action a échoué. Réessaie ou recharge la page.
        </p>
      )}
    </div>
  );
}

function ConfirmBar({
  message,
  confirmLabel,
  onCancel,
  onConfirm,
  pending,
  destructive,
}: {
  message: string;
  confirmLabel: string;
  onCancel: () => void;
  onConfirm: () => void;
  pending: boolean;
  destructive?: boolean;
}) {
  return (
    <div className="rounded-lg border bg-muted/40 p-3 space-y-3">
      <p className="text-sm">{message}</p>
      <div className="flex justify-end gap-2">
        <Button type="button" variant="ghost" size="sm" onClick={onCancel} disabled={pending}>
          Annuler
        </Button>
        <Button
          type="button"
          variant={destructive ? 'destructive' : 'default'}
          size="sm"
          onClick={onConfirm}
          disabled={pending}
        >
          {pending ? '…' : confirmLabel}
        </Button>
      </div>
    </div>
  );
}

function StatutBadge({ statut }: { statut: Boite['statut'] }) {
  const map: Record<Boite['statut'], { label: string; cls: string }> = {
    active: { label: 'Active', cls: 'bg-piloo-success text-piloo-success-on' },
    perimee: { label: 'Périmée', cls: 'bg-piloo-error text-piloo-error-on' },
    vide: { label: 'Vide', cls: 'bg-muted text-muted-foreground' },
  };
  const { label, cls } = map[statut];
  return (
    <span
      className={cn('inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium', cls)}
    >
      {label}
    </span>
  );
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-0.5">
      <dt className="text-xs uppercase tracking-wide text-muted-foreground">{label}</dt>
      <dd>{value}</dd>
    </div>
  );
}

function formatDate(iso: string): string {
  const trimmed = iso.length >= 10 ? iso.slice(0, 10) : iso;
  const d = new Date(trimmed);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
}
