// Détail d'une ordonnance : en-tête + prescriptions. Frontend de #106.
'use client';

import { $api, type components } from '@piloo/api-client';
import type { Posologie as PosologieDto } from '@piloo/api-contract';
import Link from 'next/link';
import { useParams } from 'next/navigation';

import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';

// La spec OpenAPI ne préserve pas (encore) la structure interne de Posologie ;
// on consomme donc le type Zod inferré directement depuis api-contract pour
// avoir l'autocomplétion sur les champs.
type Posologie = PosologieDto;
type Prescription = components['schemas']['Prescription'];

export default function OrdonnanceDetailPage() {
  const params = useParams<{ id: string }>();
  const { data, isLoading, error } = $api.useQuery('get', '/v1/ordonnances/{id}', {
    params: { path: { id: params.id } },
  });

  if (isLoading) return <p className="text-muted-foreground">Chargement…</p>;
  if (error || !data) {
    return (
      <div className="space-y-4">
        <p className="text-destructive">Ordonnance introuvable.</p>
        <Link href="/ordonnances">
          <Button variant="outline">← Retour aux ordonnances</Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <header>
        <Link href="/ordonnances" className="text-sm text-piloo-primary hover:underline">
          ← Toutes les ordonnances
        </Link>
        <h1 className="font-display text-3xl mt-2">
          Ordonnance du {formatDate(data.date_prescription)}
        </h1>
        <p className="text-muted-foreground">
          {data.prescripteur ?? 'Prescripteur non renseigné'} —{' '}
          <span className="uppercase text-xs tracking-wide">{data.source}</span>
        </p>
      </header>

      {data.notes && (
        <Card>
          <CardContent className="p-4 text-sm">{data.notes}</CardContent>
        </Card>
      )}

      <section>
        <h2 className="font-display text-xl mb-3">Prescriptions ({data.prescriptions.length})</h2>
        {data.prescriptions.length === 0 ? (
          <p className="text-muted-foreground">Aucune prescription dans cette ordonnance.</p>
        ) : (
          <div className="space-y-3">
            {data.prescriptions.map((p) => (
              <PrescriptionCard key={p.id} prescription={p} />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

function PrescriptionCard({ prescription }: { prescription: Prescription }) {
  return (
    <Card>
      <CardContent className="p-4 space-y-2">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h3 className="font-medium">{prescription.nom_texte}</h3>
            {prescription.cip13 && (
              <p className="text-xs text-muted-foreground">CIP {prescription.cip13}</p>
            )}
          </div>
          {prescription.duree_jours !== null && (
            <span className="text-xs px-2 py-1 rounded-full bg-piloo-primary-soft text-piloo-primary">
              {prescription.duree_jours} jour{prescription.duree_jours > 1 ? 's' : ''}
            </span>
          )}
        </div>
        <PosologieSummary posologie={prescription.posologie as unknown as Posologie} />
        {prescription.indication && (
          <p className="text-sm text-muted-foreground italic">
            Indication : {prescription.indication}
          </p>
        )}
        {prescription.notes && <p className="text-sm">{prescription.notes}</p>}
      </CardContent>
    </Card>
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
  return <p className="text-sm text-piloo-text-secondary">{parts.join(' · ')}</p>;
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  });
}
