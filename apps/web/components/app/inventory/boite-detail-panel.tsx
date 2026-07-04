// Drawer de détail d'une boîte — redesign #370.
//
// Header (icône teintée par forme + nom + forme·dosage·voie + badge statut),
// actions (ajuster stock / marquer vide / supprimer), infos clé, box
// « Références techniques » (CIP13/lot/série/ajout en mono), notes.
//
// Les actions destructives passent par une confirmation inline (pas de modal
// imbriquée dans le drawer). Le nom/forme/dosage/voie viennent de la BDPM
// résolue passée par l'inventaire (`med`).
'use client';

import {
  ArchiveBoxIcon as ArchiveBox,
  SlidersHorizontalIcon as SlidersHorizontal,
  TrashIcon as Trash,
} from '@phosphor-icons/react';
import { $api, type components } from '@piloo/api-client';
import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { Badge } from '@/components/app/badge';
import { MedIcon } from '@/components/app/med-icon';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  boiteDisplayName,
  formatDateFull,
  peremptionSeverity,
  statutBadge,
} from '@/lib/medoc/boite-display';
import { formeVisual } from '@/lib/medoc/forme';
import type { BdpmMedicament } from '@/lib/medoc/use-boite-names';
import { cn } from '@/lib/utils';

type Boite = components['schemas']['Boite'];

interface Props {
  boite: Boite;
  med: BdpmMedicament | undefined;
  onClose: () => void;
}

export function BoiteDetailPanel({ boite, med, onClose }: Props) {
  const name = boiteDisplayName(boite, med);
  const forme = formeVisual(med?.forme);
  const badge = statutBadge(boite.statut);
  const sub = [
    forme.label,
    med?.dosage,
    med?.voie_administration && `voie ${med.voie_administration}`,
  ]
    .filter(Boolean)
    .join(' · ');
  const sev = peremptionSeverity(boite.peremption);
  const peremColor =
    sev === 'err' ? 'text-piloo-error-on' : sev === 'warn' ? 'text-piloo-warning-on' : undefined;

  return (
    <div className="flex flex-col">
      <div className="border-b border-[var(--piloo-color-border-soft,var(--piloo-color-border))] px-[26px] pb-5 pt-[26px]">
        <MedIcon forme={med?.forme} size={56} className="mb-[15px]" />
        <h2 className="mb-[7px] pr-9 text-[21px] font-bold leading-tight tracking-[-.01em]">
          {name}
        </h2>
        {sub && (
          <p className="mb-[15px] text-[13.5px] text-[var(--piloo-color-text-secondary)]">{sub}</p>
        )}
        <Badge tone={badge.tone}>{badge.label}</Badge>
      </div>

      <div className="flex flex-col gap-6 px-[26px] py-[22px]">
        <BoiteActions boite={boite} onDone={onClose} />

        <dl className="flex flex-col gap-3">
          <KRow
            k="Péremption"
            v={<span className={peremColor}>{formatDateFull(boite.peremption)}</span>}
          />
          <KRow
            k="Unités restantes"
            v={`${String(boite.unites_restantes ?? '—')} / ${String(boite.unites_initiales ?? '—')}`}
          />
          {med?.titulaire && <KRow k="Titulaire" v={med.titulaire} />}
        </dl>

        <div>
          <p className="mb-[11px] text-[11px] font-bold uppercase tracking-[.06em] text-[var(--piloo-color-text-tertiary)]">
            Références techniques
          </p>
          <div className="flex flex-col gap-[11px] rounded-xl border border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-background px-4 py-3.5">
            <KRow k="Code CIP13" v={boite.cip13} mono />
            <KRow k="N° de lot" v={boite.lot ?? '—'} mono />
            <KRow k="N° de série" v={boite.numero_serie ?? '—'} mono />
            <KRow k="Ajoutée le" v={formatDateFull(boite.created_at)} mono />
          </div>
        </div>

        {boite.notes && (
          <div className="flex gap-[9px] rounded-xl bg-piloo-surfaceSubtle px-[15px] py-[13px] text-[13px] font-medium text-[var(--piloo-color-text-secondary)]">
            <span>{boite.notes}</span>
          </div>
        )}
      </div>
    </div>
  );
}

function KRow({ k, v, mono }: { k: string; v: React.ReactNode; mono?: boolean }) {
  return (
    <div className="flex items-baseline justify-between gap-4">
      <span className="shrink-0 text-[13px] text-[var(--piloo-color-text-secondary)]">{k}</span>
      <span
        className={cn(
          'text-right text-[13.5px] font-semibold',
          mono && 'font-mono text-[12.5px] font-medium',
        )}
      >
        {v}
      </span>
    </div>
  );
}

type ConfirmAction = 'vide' | 'delete' | null;

function BoiteActions({ boite, onDone }: { boite: Boite; onDone: () => void }) {
  const queryClient = useQueryClient();
  const [confirming, setConfirming] = useState<ConfirmAction>(null);
  const [adjusting, setAdjusting] = useState(false);
  const [stockDraft, setStockDraft] = useState<string>(
    boite.unites_restantes !== null ? String(boite.unites_restantes) : '',
  );

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: ['get', '/v1/officines/{officineId}/boites'] });
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
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap gap-2">
        <Button
          type="button"
          variant="secondary"
          size="sm"
          disabled={isBusy}
          onClick={() => {
            setAdjusting((v) => !v);
            setConfirming(null);
          }}
        >
          <SlidersHorizontal size={17} />
          Ajuster le stock
        </Button>
        {boite.statut !== 'vide' && (
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={isBusy}
            onClick={() => {
              setConfirming('vide');
              setAdjusting(false);
            }}
          >
            <ArchiveBox size={17} />
            Marquer vide
          </Button>
        )}
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="text-piloo-error-on hover:bg-piloo-error"
          disabled={isBusy}
          onClick={() => {
            setConfirming('delete');
            setAdjusting(false);
          }}
        >
          <Trash size={17} />
        </Button>
      </div>

      {adjusting && (
        <div className="flex flex-col gap-2 rounded-xl border border-border bg-piloo-background p-3">
          <Label htmlFor="stock-adjust" className="text-[13px]">
            Unités restantes
          </Label>
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
      )}

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
      {confirming === 'delete' && (
        <ConfirmBar
          message="Supprimer définitivement cette boîte de l'inventaire ?"
          confirmLabel="Supprimer"
          destructive
          onCancel={() => {
            setConfirming(null);
          }}
          onConfirm={() => {
            deleteMutation.mutate({ params: { path: { id: boite.id } } });
          }}
          pending={deleteMutation.isPending}
        />
      )}

      {(patchMutation.error ?? deleteMutation.error) && (
        <p className="text-sm text-piloo-error-on">
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
    <div className="flex flex-col gap-3 rounded-xl border border-border bg-piloo-surfaceSubtle p-3">
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
