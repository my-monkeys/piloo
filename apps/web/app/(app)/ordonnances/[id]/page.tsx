// Détail d'une ordonnance : en-tête + prescriptions (#106), harmonisé au
// système du redesign (#370) — prescriptions name-first + icône de forme.
'use client';

import { ArrowLeftIcon as ArrowLeft } from '@phosphor-icons/react';
import { $api, type components } from '@piloo/api-client';
import type { Posologie as PosologieDto } from '@piloo/api-contract';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useMemo } from 'react';

import { Badge } from '@/components/app/badge';
import { MedIcon } from '@/components/app/med-icon';
import { PageHeader } from '@/components/app/page-header';
import { Panel } from '@/components/app/panel';
import { Button } from '@/components/ui/button';
import { useBoiteNames } from '@/lib/medoc/use-boite-names';

type Posologie = PosologieDto;
type Prescription = components['schemas']['Prescription'];

export default function OrdonnanceDetailPage() {
  const params = useParams<{ id: string }>();
  const { data, isLoading, error } = $api.useQuery('get', '/v1/ordonnances/{id}', {
    params: { path: { id: params.id } },
  });

  const cips = useMemo(
    () => (data?.prescriptions ?? []).map((p) => p.cip13).filter((c): c is string => !!c),
    [data],
  );
  const { byCip } = useBoiteNames(cips);

  if (isLoading)
    return <p className="text-sm text-[var(--piloo-color-text-tertiary)]">Chargement…</p>;
  if (error || !data) {
    return (
      <div className="flex flex-col items-start gap-4">
        <p className="text-sm text-piloo-error-on">Ordonnance introuvable.</p>
        <Button asChild variant="outline" size="sm">
          <Link href="/ordonnances">
            <ArrowLeft size={16} />
            Retour aux ordonnances
          </Link>
        </Button>
      </div>
    );
  }

  return (
    <>
      <Link
        href="/ordonnances"
        className="mb-2 inline-flex items-center gap-1.5 text-[13px] font-semibold text-piloo-primary hover:underline"
      >
        <ArrowLeft size={15} />
        Toutes les ordonnances
      </Link>
      <PageHeader
        eyebrow={data.prescripteur ?? 'Prescripteur non renseigné'}
        title={`Ordonnance du ${formatDate(data.date_prescription)}`}
        action={<Badge tone="neutral">{data.source === 'ocr' ? 'OCR' : 'Manuelle'}</Badge>}
      />

      {data.notes && (
        <Panel className="mb-4">
          <p className="text-sm text-[var(--piloo-color-text-secondary)]">{data.notes}</p>
        </Panel>
      )}

      <h2 className="mb-3 text-[13px] font-bold uppercase tracking-[.06em] text-[var(--piloo-color-text-tertiary)]">
        Prescriptions ({data.prescriptions.length})
      </h2>
      {data.prescriptions.length === 0 ? (
        <Panel>
          <p className="text-sm text-[var(--piloo-color-text-tertiary)]">Aucune prescription.</p>
        </Panel>
      ) : (
        <div className="flex flex-col gap-3">
          {data.prescriptions.map((p) => (
            <PrescriptionCard
              key={p.id}
              prescription={p}
              forme={p.cip13 ? byCip.get(p.cip13)?.forme : undefined}
            />
          ))}
        </div>
      )}
    </>
  );
}

function PrescriptionCard({
  prescription,
  forme,
}: {
  prescription: Prescription;
  forme: string | null | undefined;
}) {
  return (
    <Panel>
      <div className="flex items-start gap-[13px]">
        <MedIcon forme={forme} size={42} />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h3 className="text-[15px] font-semibold">{prescription.nom_texte}</h3>
            {prescription.duree_jours !== null && (
              <Badge tone="neutral">
                {prescription.duree_jours} jour{prescription.duree_jours > 1 ? 's' : ''}
              </Badge>
            )}
          </div>
          <PosologieSummary posologie={prescription.posologie as unknown as Posologie} />
          {prescription.indication && (
            <p className="mt-1 text-[13px] italic text-[var(--piloo-color-text-tertiary)]">
              Indication : {prescription.indication}
            </p>
          )}
          {prescription.notes && <p className="mt-1 text-[13px]">{prescription.notes}</p>}
          {prescription.cip13 && (
            <p className="mt-1.5 font-mono text-[10.5px] text-[var(--piloo-color-text-tertiary)]">
              CIP {prescription.cip13}
            </p>
          )}
        </div>
      </div>
    </Panel>
  );
}

function PosologieSummary({ posologie }: { posologie: Posologie }) {
  const parts: string[] = [`${String(posologie.unitesParPrise)} ${posologie.unite} par prise`];
  if (posologie.frequence === 'a_la_demande') {
    parts.push('à la demande');
  } else {
    const cadence = posologie.frequence === 'hebdomadaire' ? 'par semaine' : 'par jour';
    const moments = posologie.moments?.join(', ');
    const horaires = posologie.horaires?.join(', ');
    if (horaires) parts.push(`à ${horaires}`);
    else if (moments) parts.push(`(${moments}) ${cadence}`);
    else parts.push(cadence);
  }
  if (posologie.avecRepas) parts.push('avec repas');
  return (
    <p className="mt-0.5 text-[13px] text-[var(--piloo-color-text-secondary)]">
      {parts.join(' · ')}
    </p>
  );
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  });
}
