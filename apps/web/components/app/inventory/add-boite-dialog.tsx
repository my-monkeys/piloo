// Dialog "Ajouter une boîte" sur la page Inventaire.
//
// L'inventaire est read-only sans ce composant — c'est le déblocage qui
// rend Piloo utilisable pour l'armoire à pharmacie maison en attendant
// le scan mobile (cf. PR feat/web-ajout-boite-manuelle).
//
// Flow :
//   1. Recherche BDPM (nom ou CIP) → liste de médicaments.
//   2. Sélection d'un médicament → fixe le CIP13.
//      Si BDPM ne donne pas de CIP13 (rare), on bloque : la boîte a un
//      CIP13 NOT NULL en DB. L'utilisateur recolle un autre résultat.
//   3. Saisie péremption + stock + lot + notes → POST.
//
// On ne gère pas (volontairement) :
//   - le DataMatrix scanné (mobile-only, hors scope).
//   - l'édition d'une boîte existante (action séparée dans le panneau détail).
'use client';

import { PlusIcon as Plus } from '@phosphor-icons/react';
import { $api, type components } from '@piloo/api-client';
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';

import { MedIcon } from '@/components/app/med-icon';
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

type BdpmMedicament = components['schemas']['BdpmMedicament'];

const SEARCH_DEBOUNCE_MS = 250;
const SEARCH_MIN_CHARS = 2;

interface Props {
  officineId: string;
}

export function AddBoiteDialog({ officineId }: Props) {
  const queryClient = useQueryClient();
  const [open, setOpen] = useState(false);
  const [selected, setSelected] = useState<BdpmMedicament | null>(null);
  const [peremption, setPeremption] = useState('');
  const [unitesInitiales, setUnitesInitiales] = useState('');
  const [unitesRestantes, setUnitesRestantes] = useState('');
  const [lot, setLot] = useState('');
  const [notes, setNotes] = useState('');

  const createMutation = $api.useMutation('post', '/v1/officines/{officineId}/boites', {
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ['get', '/v1/officines/{officineId}/boites'],
      });
      reset();
      setOpen(false);
    },
  });

  function reset() {
    setSelected(null);
    setPeremption('');
    setUnitesInitiales('');
    setUnitesRestantes('');
    setLot('');
    setNotes('');
  }

  // Le CIP13 est obligatoire en DB ; on s'assure que le médicament BDPM
  // sélectionné en a bien un avant de soumettre.
  const cip13 = selected?.cip13 ?? null;
  const canSubmit = cip13 !== null && peremption !== '' && !createMutation.isPending;

  function handleSubmit(e: React.SyntheticEvent) {
    e.preventDefault();
    if (cip13 === null || peremption === '') return;
    createMutation.mutate({
      params: { path: { officineId } },
      body: {
        cip13,
        peremption,
        lot: lot.trim() === '' ? null : lot.trim(),
        unites_initiales: parseUnits(unitesInitiales),
        unites_restantes: parseUnits(unitesRestantes),
        notes: notes.trim() === '' ? null : notes.trim(),
      },
    });
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
        <Button>
          <Plus size={17} />
          Ajouter une boîte
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Ajouter une boîte</DialogTitle>
          <DialogDescription>
            Cherche le médicament dans la base officielle française (BDPM), puis renseigne la
            péremption et le stock.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-5">
          <BdpmPicker selected={selected} onSelect={setSelected} />

          {selected?.cip13 === null && (
            <p className="text-sm text-destructive">
              Ce médicament n&apos;a pas de CIP13 en base BDPM, on ne peut pas créer la boîte
              dessus. Choisis un autre résultat.
            </p>
          )}

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="peremption">Péremption *</Label>
              <Input
                id="peremption"
                type="date"
                value={peremption}
                onChange={(e) => {
                  setPeremption(e.target.value);
                }}
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="lot">Lot</Label>
              <Input
                id="lot"
                value={lot}
                onChange={(e) => {
                  setLot(e.target.value);
                }}
                placeholder="optionnel"
                maxLength={64}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="unites-initiales">Unités à l&apos;ouverture</Label>
              <Input
                id="unites-initiales"
                type="number"
                min={1}
                inputMode="numeric"
                value={unitesInitiales}
                onChange={(e) => {
                  setUnitesInitiales(e.target.value);
                  // Pré-remplit le stock restant à l'identique tant que
                  // l'utilisateur ne l'a pas touché — ergonomie boîte neuve.
                  if (unitesRestantes === '' || unitesRestantes === unitesInitiales) {
                    setUnitesRestantes(e.target.value);
                  }
                }}
                placeholder="ex. 30"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="unites-restantes">Unités restantes</Label>
              <Input
                id="unites-restantes"
                type="number"
                min={0}
                inputMode="numeric"
                value={unitesRestantes}
                onChange={(e) => {
                  setUnitesRestantes(e.target.value);
                }}
                placeholder="ex. 24"
              />
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="notes">Notes</Label>
            <Input
              id="notes"
              value={notes}
              onChange={(e) => {
                setNotes(e.target.value);
              }}
              placeholder="ex. dans l'armoire de la cuisine"
              maxLength={2000}
            />
          </div>

          {createMutation.error && (
            <p className="text-sm text-destructive">
              Impossible d&apos;enregistrer la boîte (l&apos;API a refusé). Réessaie.
            </p>
          )}

          <DialogFooter>
            <Button type="submit" disabled={!canSubmit}>
              {createMutation.isPending ? 'Enregistrement…' : 'Enregistrer la boîte'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function parseUnits(raw: string): number | null {
  const t = raw.trim();
  if (t === '') return null;
  const n = Number(t);
  if (!Number.isFinite(n) || n < 0 || !Number.isInteger(n)) return null;
  return n;
}

function BdpmPicker({
  selected,
  onSelect,
}: {
  selected: BdpmMedicament | null;
  onSelect: (m: BdpmMedicament | null) => void;
}) {
  const [query, setQuery] = useState('');
  const [debounced, setDebounced] = useState('');

  useEffect(() => {
    const handle = setTimeout(() => {
      setDebounced(query.trim());
    }, SEARCH_DEBOUNCE_MS);
    return () => {
      clearTimeout(handle);
    };
  }, [query]);

  const enabled = debounced.length >= SEARCH_MIN_CHARS && selected === null;

  const { data, isFetching } = $api.useQuery(
    'get',
    '/v1/bdpm/search',
    { params: { query: { q: debounced } } },
    { enabled },
  );

  const items = useMemo(() => data?.items ?? [], [data]);

  if (selected) {
    return (
      <div className="flex items-start gap-3 rounded-xl border border-border bg-piloo-surface p-3">
        <MedIcon forme={selected.forme} size={42} />
        <div className="min-w-0 flex-1">
          <p className="text-[15px] font-semibold leading-tight">{selected.denomination}</p>
          <p className="text-[12.5px] text-[var(--piloo-color-text-tertiary)]">
            {[selected.forme, selected.dosage].filter(Boolean).join(' · ') || 'Forme inconnue'}
          </p>
          <p className="mt-1 font-mono text-[10.5px] text-[var(--piloo-color-text-tertiary)]">
            CIP {selected.cip13 ?? '—'} · CIS {selected.cis}
          </p>
        </div>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          onClick={() => {
            onSelect(null);
          }}
        >
          Changer
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <Label htmlFor="bdpm-search">Médicament *</Label>
      <Input
        id="bdpm-search"
        value={query}
        onChange={(e) => {
          setQuery(e.target.value);
        }}
        placeholder="ex. Doliprane 500 ou 3400934567890"
        autoFocus
      />

      {!enabled && (
        <p className="text-xs text-muted-foreground">
          Tape au moins 2 caractères du nom, ou un CIP (7 ou 13 chiffres).
        </p>
      )}

      {enabled && isFetching && <p className="text-xs text-muted-foreground">Recherche…</p>}

      {enabled && !isFetching && items.length === 0 && (
        <p className="text-xs text-muted-foreground">Aucun résultat.</p>
      )}

      {items.length > 0 && (
        <ul className="max-h-64 overflow-y-auto rounded-xl border border-border bg-piloo-surface">
          {items.map((m) => (
            <li key={m.cis}>
              <button
                type="button"
                onClick={() => {
                  onSelect(m);
                }}
                className="flex w-full items-center gap-3 border-b border-[var(--piloo-color-border-soft,var(--piloo-color-border))] p-3 text-left transition-colors last:border-b-0 hover:bg-piloo-surfaceSubtle"
              >
                <MedIcon forme={m.forme} size={38} />
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-semibold leading-tight">
                    {m.denomination}
                  </span>
                  <span className="block text-xs text-[var(--piloo-color-text-tertiary)]">
                    {[m.forme, m.dosage].filter(Boolean).join(' · ') || '—'}
                  </span>
                  <span className="block font-mono text-[10.5px] text-[var(--piloo-color-text-tertiary)]">
                    CIP {m.cip13 ?? '—'}
                  </span>
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
