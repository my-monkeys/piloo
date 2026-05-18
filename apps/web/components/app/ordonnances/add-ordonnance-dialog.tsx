// Dialog "Nouvelle ordonnance" sur la page Ordonnances.
//
// Sans ce composant, l'utilisateur ne peut pas saisir d'ordonnance →
// pas de prises_planifiees générées → timeline vide. C'est le second
// déblocage (avec l'ajout de boîte) pour rendre l'app utilisable à la
// maison sans le scan mobile.
//
// Choix de scope :
//   - 1 dialog, N prescriptions ajoutables inline (CreateOrdonnanceInput
//     accepte le nesting → un seul round-trip).
//   - Posologie simplifiée par défaut : frequence=quotidien + choix des
//     moments (matin/midi/soir/coucher) + 1 unité par prise. Le mode
//     "horaires précis" / "à la demande" / "hebdomadaire" est exposé
//     en sélection mais sans surcharge d'UI.
//   - Le nom du médicament est libre (texte), avec autocomplete BDPM
//     facultatif qui pré-remplit CIP13 + nom. L'utilisateur peut saisir
//     n'importe quoi sans CIP (ordonnances vétérinaires, magistrales,
//     compléments, etc.).
'use client';

import { $api, type components } from '@piloo/api-client';
import type { Posologie } from '@piloo/api-contract';
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';

import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { cn } from '@/lib/utils';

type BdpmMedicament = components['schemas']['BdpmMedicament'];
type Frequence = Posologie['frequence'];
type Moment = NonNullable<Posologie['moments']>[number];

interface PrescriptionDraft {
  id: string;
  nomTexte: string;
  cip13: string | null;
  cis: string | null;
  unitesParPrise: string;
  unite: string;
  frequence: Frequence;
  moments: Moment[];
  avecRepas: boolean;
  dureeJours: string;
  indication: string;
  notes: string;
}

interface Props {
  officineId: string;
}

const ALL_MOMENTS: Moment[] = ['matin', 'midi', 'soir', 'coucher'];

function makeDraft(): PrescriptionDraft {
  return {
    id: crypto.randomUUID(),
    nomTexte: '',
    cip13: null,
    cis: null,
    unitesParPrise: '1',
    unite: 'comprimé',
    frequence: 'quotidien',
    moments: ['matin'],
    avecRepas: false,
    dureeJours: '',
    indication: '',
    notes: '',
  };
}

export function AddOrdonnanceDialog({ officineId }: Props) {
  const queryClient = useQueryClient();
  const [open, setOpen] = useState(false);
  const [datePrescription, setDatePrescription] = useState(today());
  const [prescripteur, setPrescripteur] = useState('');
  const [notes, setNotes] = useState('');
  const [prescriptions, setPrescriptions] = useState<PrescriptionDraft[]>([makeDraft()]);

  const createMutation = $api.useMutation('post', '/v1/officines/{officineId}/ordonnances', {
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ['get', '/v1/officines/{officineId}/ordonnances'],
      });
      reset();
      setOpen(false);
    },
  });

  function reset() {
    setDatePrescription(today());
    setPrescripteur('');
    setNotes('');
    setPrescriptions([makeDraft()]);
  }

  const validation = useMemo(() => validatePrescriptions(prescriptions), [prescriptions]);
  const canSubmit = datePrescription !== '' && validation.ok && !createMutation.isPending;

  function handleSubmit(e: React.SyntheticEvent) {
    e.preventDefault();
    if (!validation.ok) return;
    createMutation.mutate({
      params: { path: { officineId } },
      body: {
        date_prescription: datePrescription,
        prescripteur: prescripteur.trim() === '' ? null : prescripteur.trim(),
        notes: notes.trim() === '' ? null : notes.trim(),
        source: 'manuelle',
        prescriptions: validation.payload,
      },
    });
  }

  function updateDraft(id: string, patch: Partial<PrescriptionDraft>) {
    setPrescriptions((prev) => prev.map((d) => (d.id === id ? { ...d, ...patch } : d)));
  }
  function removeDraft(id: string) {
    setPrescriptions((prev) => (prev.length === 1 ? prev : prev.filter((d) => d.id !== id)));
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        setOpen(o);
        if (!o) {
          reset();
          createMutation.reset();
        }
      }}
    >
      <DialogTrigger asChild>
        <Button>+ Nouvelle ordonnance</Button>
      </DialogTrigger>
      <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Nouvelle ordonnance</DialogTitle>
          <DialogDescription>
            Saisis les informations d&apos;une ordonnance. Les prises seront générées
            automatiquement dans la timeline.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="date-prescription">Date de prescription *</Label>
              <Input
                id="date-prescription"
                type="date"
                value={datePrescription}
                onChange={(e) => {
                  setDatePrescription(e.target.value);
                }}
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="prescripteur">Prescripteur</Label>
              <Input
                id="prescripteur"
                value={prescripteur}
                onChange={(e) => {
                  setPrescripteur(e.target.value);
                }}
                placeholder="Dr Dupont"
                maxLength={255}
              />
            </div>
          </div>
          <div className="space-y-2">
            <Label htmlFor="ord-notes">Notes</Label>
            <Input
              id="ord-notes"
              value={notes}
              onChange={(e) => {
                setNotes(e.target.value);
              }}
              placeholder="optionnel"
              maxLength={2000}
            />
          </div>

          <div className="space-y-3 border-t pt-4">
            <div className="flex items-center justify-between">
              <h3 className="font-medium">Prescriptions ({prescriptions.length})</h3>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => {
                  setPrescriptions((prev) => [...prev, makeDraft()]);
                }}
              >
                + Ajouter
              </Button>
            </div>
            {prescriptions.map((draft, idx) => (
              <PrescriptionEditor
                key={draft.id}
                draft={draft}
                index={idx}
                canRemove={prescriptions.length > 1}
                onChange={(patch) => {
                  updateDraft(draft.id, patch);
                }}
                onRemove={() => {
                  removeDraft(draft.id);
                }}
              />
            ))}
          </div>

          {!validation.ok && validation.error && (
            <p className="text-sm text-destructive">{validation.error}</p>
          )}
          {createMutation.error && (
            <p className="text-sm text-destructive">
              L&apos;API a refusé. Vérifie les champs et réessaie.
            </p>
          )}

          <DialogFooter>
            <Button type="submit" disabled={!canSubmit}>
              {createMutation.isPending ? 'Enregistrement…' : 'Enregistrer l’ordonnance'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function PrescriptionEditor({
  draft,
  index,
  canRemove,
  onChange,
  onRemove,
}: {
  draft: PrescriptionDraft;
  index: number;
  canRemove: boolean;
  onChange: (patch: Partial<PrescriptionDraft>) => void;
  onRemove: () => void;
}) {
  return (
    <div className="rounded-lg border bg-card p-4 space-y-4">
      <div className="flex items-start justify-between gap-3">
        <h4 className="text-sm font-medium text-muted-foreground">Prescription {index + 1}</h4>
        {canRemove && (
          <Button type="button" variant="ghost" size="sm" onClick={onRemove}>
            Retirer
          </Button>
        )}
      </div>

      <MedicamentPicker
        nomTexte={draft.nomTexte}
        cip13={draft.cip13}
        onPick={(nom, m) => {
          onChange({
            nomTexte: nom,
            cip13: m?.cip13 ?? null,
            cis: m?.cis ?? null,
          });
        }}
      />

      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label htmlFor={`unites-${draft.id}`}>Unités par prise *</Label>
          <Input
            id={`unites-${draft.id}`}
            type="number"
            min={0.25}
            step={0.25}
            value={draft.unitesParPrise}
            onChange={(e) => {
              onChange({ unitesParPrise: e.target.value });
            }}
          />
        </div>
        <div className="space-y-2">
          <Label htmlFor={`unite-${draft.id}`}>Unité *</Label>
          <Input
            id={`unite-${draft.id}`}
            value={draft.unite}
            onChange={(e) => {
              onChange({ unite: e.target.value });
            }}
            placeholder="comprimé, ml, sachet…"
            maxLength={32}
          />
        </div>
      </div>

      <div className="space-y-2">
        <Label>Fréquence *</Label>
        <div className="flex flex-wrap gap-2">
          <FrequenceChip
            value="quotidien"
            current={draft.frequence}
            onClick={(f) => {
              onChange({ frequence: f });
            }}
          >
            Quotidien
          </FrequenceChip>
          <FrequenceChip
            value="hebdomadaire"
            current={draft.frequence}
            onClick={(f) => {
              onChange({ frequence: f });
            }}
          >
            Hebdomadaire
          </FrequenceChip>
          <FrequenceChip
            value="a_la_demande"
            current={draft.frequence}
            onClick={(f) => {
              onChange({ frequence: f });
            }}
          >
            À la demande
          </FrequenceChip>
        </div>
      </div>

      {draft.frequence !== 'a_la_demande' && (
        <div className="space-y-2">
          <Label>Moments de prise *</Label>
          <div className="flex flex-wrap gap-2">
            {ALL_MOMENTS.map((m) => (
              <MomentChip
                key={m}
                value={m}
                selected={draft.moments.includes(m)}
                onToggle={(picked) => {
                  onChange({
                    moments: picked ? [...draft.moments, m] : draft.moments.filter((x) => x !== m),
                  });
                }}
              >
                {MOMENT_LABEL[m]}
              </MomentChip>
            ))}
          </div>
        </div>
      )}

      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label htmlFor={`duree-${draft.id}`}>Durée (jours)</Label>
          <Input
            id={`duree-${draft.id}`}
            type="number"
            min={1}
            value={draft.dureeJours}
            onChange={(e) => {
              onChange({ dureeJours: e.target.value });
            }}
            placeholder="vide = à vie"
          />
        </div>
        <div className="space-y-2 flex flex-col">
          <Label htmlFor={`repas-${draft.id}`}>Avec repas</Label>
          <label className="flex items-center gap-2 text-sm pt-2">
            <input
              id={`repas-${draft.id}`}
              type="checkbox"
              checked={draft.avecRepas}
              onChange={(e) => {
                onChange({ avecRepas: e.target.checked });
              }}
            />
            Prendre pendant un repas
          </label>
        </div>
      </div>

      <div className="space-y-2">
        <Label htmlFor={`indication-${draft.id}`}>Indication</Label>
        <Input
          id={`indication-${draft.id}`}
          value={draft.indication}
          onChange={(e) => {
            onChange({ indication: e.target.value });
          }}
          placeholder="ex. fièvre, douleur"
          maxLength={255}
        />
      </div>
      <div className="space-y-2">
        <Label htmlFor={`pres-notes-${draft.id}`}>Notes</Label>
        <Input
          id={`pres-notes-${draft.id}`}
          value={draft.notes}
          onChange={(e) => {
            onChange({ notes: e.target.value });
          }}
          placeholder="optionnel"
          maxLength={2000}
        />
      </div>
    </div>
  );
}

function FrequenceChip({
  value,
  current,
  onClick,
  children,
}: {
  value: Frequence;
  current: Frequence;
  onClick: (v: Frequence) => void;
  children: React.ReactNode;
}) {
  const selected = value === current;
  return (
    <button
      type="button"
      className={cn(
        'rounded-full px-3 py-1 text-sm border transition-colors',
        selected
          ? 'bg-piloo-primary text-piloo-primary-on border-transparent'
          : 'bg-background hover:bg-accent',
      )}
      onClick={() => {
        onClick(value);
      }}
    >
      {children}
    </button>
  );
}

function MomentChip({
  value,
  selected,
  onToggle,
  children,
}: {
  value: Moment;
  selected: boolean;
  onToggle: (selected: boolean) => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      data-value={value}
      className={cn(
        'rounded-full px-3 py-1 text-sm border transition-colors',
        selected
          ? 'bg-piloo-primary text-piloo-primary-on border-transparent'
          : 'bg-background hover:bg-accent',
      )}
      onClick={() => {
        onToggle(!selected);
      }}
    >
      {children}
    </button>
  );
}

const MOMENT_LABEL: Record<Moment, string> = {
  matin: 'Matin',
  midi: 'Midi',
  soir: 'Soir',
  coucher: 'Coucher',
};

const SEARCH_DEBOUNCE_MS = 250;
const SEARCH_MIN_CHARS = 2;

function MedicamentPicker({
  nomTexte,
  cip13,
  onPick,
}: {
  nomTexte: string;
  cip13: string | null;
  onPick: (nom: string, match: BdpmMedicament | null) => void;
}) {
  const [debounced, setDebounced] = useState('');
  const [focused, setFocused] = useState(false);

  useEffect(() => {
    const handle = setTimeout(() => {
      setDebounced(nomTexte.trim());
    }, SEARCH_DEBOUNCE_MS);
    return () => {
      clearTimeout(handle);
    };
  }, [nomTexte]);

  const enabled = focused && debounced.length >= SEARCH_MIN_CHARS && cip13 === null;
  const { data, isFetching } = $api.useQuery(
    'get',
    '/v1/bdpm/search',
    { params: { query: { q: debounced } } },
    { enabled },
  );

  const items = useMemo(() => data?.items ?? [], [data]);

  return (
    <div className="space-y-2 relative">
      <Label htmlFor="med-name">Médicament *</Label>
      <Input
        id="med-name"
        value={nomTexte}
        onChange={(e) => {
          onPick(e.target.value, null);
        }}
        onFocus={() => {
          setFocused(true);
        }}
        onBlur={() => {
          // Délai pour laisser passer le click sur la liste avant blur.
          setTimeout(() => {
            setFocused(false);
          }, 150);
        }}
        placeholder="ex. Doliprane 500"
        autoComplete="off"
        required
      />
      {cip13 !== null && (
        <p className="text-xs text-muted-foreground">
          CIP13 : <span className="font-mono">{cip13}</span> ·{' '}
          <button
            type="button"
            className="underline"
            onClick={() => {
              onPick(nomTexte, null);
            }}
          >
            détacher
          </button>
        </p>
      )}

      {enabled && (items.length > 0 || isFetching) && (
        <ul className="absolute z-20 left-0 right-0 mt-1 max-h-56 overflow-y-auto rounded-lg border bg-popover shadow-md">
          {isFetching && items.length === 0 && (
            <li className="p-3 text-xs text-muted-foreground">Recherche…</li>
          )}
          {items.map((m) => (
            <li key={m.cis}>
              <button
                type="button"
                onMouseDown={(e) => {
                  // mousedown plutôt que click pour éviter blur avant pick
                  e.preventDefault();
                  onPick(m.denomination, m);
                  setFocused(false);
                }}
                className="w-full text-left p-3 hover:bg-accent border-b last:border-b-0 transition-colors"
              >
                <p className="text-sm font-medium leading-tight">{m.denomination}</p>
                <p className="text-xs text-muted-foreground">
                  {[m.forme, m.dosage].filter(Boolean).join(' — ') || '—'} · CIP13 {m.cip13 ?? '—'}
                </p>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

type Validation =
  | { ok: true; payload: components['schemas']['CreatePrescriptionInput'][] }
  | { ok: false; error: string };

function validatePrescriptions(drafts: PrescriptionDraft[]): Validation {
  if (drafts.length === 0) return { ok: false, error: 'Ajoute au moins une prescription.' };
  const payload: components['schemas']['CreatePrescriptionInput'][] = [];
  for (const [idx, d] of drafts.entries()) {
    const tag = `Prescription ${String(idx + 1)} : `;
    const nom = d.nomTexte.trim();
    if (nom === '') return { ok: false, error: `${tag}nom du médicament manquant.` };
    if (d.unite.trim() === '') return { ok: false, error: `${tag}unité manquante.` };
    const u = Number(d.unitesParPrise);
    if (!Number.isFinite(u) || u <= 0)
      return { ok: false, error: `${tag}unités par prise invalides.` };
    if (d.frequence !== 'a_la_demande' && d.moments.length === 0) {
      return { ok: false, error: `${tag}choisis au moins un moment.` };
    }
    let dureeJours: number | null = null;
    if (d.dureeJours.trim() !== '') {
      const n = Number(d.dureeJours);
      if (!Number.isInteger(n) || n <= 0 || n > 3650) {
        return { ok: false, error: `${tag}durée invalide (entier 1..3650).` };
      }
      dureeJours = n;
    }
    const posologie: Posologie = {
      unitesParPrise: u,
      unite: d.unite.trim(),
      frequence: d.frequence,
      ...(d.frequence !== 'a_la_demande' && { moments: d.moments }),
      ...(d.avecRepas && { avecRepas: true }),
    };
    payload.push({
      nom_texte: nom,
      cip13: d.cip13,
      cis: d.cis,
      posologie,
      duree_jours: dureeJours,
      indication: d.indication.trim() === '' ? null : d.indication.trim(),
      notes: d.notes.trim() === '' ? null : d.notes.trim(),
    });
  }
  return { ok: true, payload };
}

function today(): string {
  const d = new Date();
  const y = d.getFullYear();
  const m = (d.getMonth() + 1).toString().padStart(2, '0');
  const day = d.getDate().toString().padStart(2, '0');
  return `${String(y)}-${m}-${day}`;
}
