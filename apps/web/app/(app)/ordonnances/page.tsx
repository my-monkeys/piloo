// Page Ordonnances — liste des ordonnances de l'officine active (#106),
// harmonisée au système du redesign (#370) : PageHeader + lignes en carte.
'use client';

import {
  CaretRightIcon as CaretRight,
  PrescriptionIcon as Prescription,
} from '@phosphor-icons/react';
import { $api } from '@piloo/api-client';
import Link from 'next/link';

import { Badge } from '@/components/app/badge';
import { PageHeader } from '@/components/app/page-header';
import { Panel } from '@/components/app/panel';
import { AddOrdonnanceDialog } from '@/components/app/ordonnances/add-ordonnance-dialog';
import { useActiveOfficine } from '@/lib/officines/active-officine';
import { useActiveOfficineName } from '@/lib/officines/use-active-officine-name';

export default function OrdonnancesPage() {
  const { activeOfficineId } = useActiveOfficine();
  const officineName = useActiveOfficineName();

  return (
    <>
      <PageHeader
        eyebrow={officineName}
        title="Ordonnances"
        action={
          activeOfficineId ? <AddOrdonnanceDialog officineId={activeOfficineId} /> : undefined
        }
      />
      {!activeOfficineId ? (
        <Panel>
          <p className="text-sm text-[var(--piloo-color-text-tertiary)]">
            Sélectionne une officine pour voir ses ordonnances.
          </p>
        </Panel>
      ) : (
        <OrdonnancesList officineId={activeOfficineId} />
      )}
    </>
  );
}

function OrdonnancesList({ officineId }: { officineId: string }) {
  const { data, isLoading, error } = $api.useQuery(
    'get',
    '/v1/officines/{officineId}/ordonnances',
    {
      params: { path: { officineId } },
    },
  );

  if (isLoading) return <Muted>Chargement…</Muted>;
  if (error)
    return (
      <Panel>
        <Muted>Impossible de charger les ordonnances.</Muted>
      </Panel>
    );

  const items = data?.items ?? [];
  if (items.length === 0)
    return (
      <Panel>
        <Muted>Aucune ordonnance — celles que tu saisis apparaîtront ici.</Muted>
      </Panel>
    );

  return (
    <div className="overflow-hidden rounded-2xl border border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-surface shadow-[0_1px_2px_rgba(37,42,48,.03),0_10px_26px_-18px_rgba(37,42,48,.14)]">
      {items.map((ord) => (
        <Link
          key={ord.id}
          href={`/ordonnances/${ord.id}`}
          className="flex items-center gap-4 border-t border-[var(--piloo-color-border-soft,var(--piloo-color-border))] px-5 py-3.5 transition-colors first:border-t-0 hover:bg-piloo-surfaceSubtle"
        >
          <span className="grid h-[42px] w-[42px] shrink-0 place-items-center rounded-xl bg-piloo-primary-soft text-piloo-primary-hover">
            <Prescription size={22} weight="fill" />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-[15px] font-semibold">
              {ord.prescripteur ?? 'Ordonnance'}
            </span>
            <span className="block text-[12.5px] text-[var(--piloo-color-text-tertiary)]">
              {formatDate(ord.date_prescription)}
              {ord.notes ? ` · ${ord.notes}` : ''}
            </span>
          </span>
          <Badge tone="neutral">{ord.source === 'ocr' ? 'OCR' : 'Manuelle'}</Badge>
          <CaretRight
            size={16}
            className="hidden text-[var(--piloo-color-text-tertiary)] sm:block"
          />
        </Link>
      ))}
    </div>
  );
}

function Muted({ children }: { children: React.ReactNode }) {
  return <p className="text-sm text-[var(--piloo-color-text-tertiary)]">{children}</p>;
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  });
}
