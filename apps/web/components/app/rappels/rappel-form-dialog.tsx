// Dialog "Modifier le rappel" (#355).
//
// Pré-remplit les champs depuis le rappel existant. Soumet un PATCH
// `/v1/rappels/{id}` avec les valeurs modifiées.
// Les champs quantité sont clearables (vide → null = moment désactivé).
'use client';

import { $api, type components } from '@piloo/api-client';
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';

import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

type Rappel = components['schemas']['Rappel'];

interface Props {
  rappel: Rappel;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

// Parse un champ texte de nombre → number | null
function parseQty(raw: string): number | null {
  const t = raw.trim();
  if (t === '') return null;
  const n = parseFloat(t);
  if (!Number.isFinite(n) || n < 0) return null;
  return n;
}

// Formate un number | null → string pour l'input
function fmtQty(v: number | null): string {
  return v != null ? String(v) : '';
}

export function RappelFormDialog({ rappel, open, onOpenChange }: Props) {
  const queryClient = useQueryClient();

  // Champs du formulaire
  const [unite, setUnite] = useState(rappel.unite);
  const [matin, setMatin] = useState(fmtQty(rappel.quantite_matin));
  const [midi, setMidi] = useState(fmtQty(rappel.quantite_midi));
  const [soir, setSoir] = useState(fmtQty(rappel.quantite_soir));
  const [coucher, setCoucher] = useState(fmtQty(rappel.quantite_coucher));
  const [dateDebut, setDateDebut] = useState(rappel.date_debut);
  const [dateFin, setDateFin] = useState(rappel.date_fin ?? '');
  const [notes, setNotes] = useState(rappel.notes ?? '');

  // Resync quand le rappel change (ex: édition de la même ligne après un PATCH)
  useEffect(() => {
    setUnite(rappel.unite);
    setMatin(fmtQty(rappel.quantite_matin));
    setMidi(fmtQty(rappel.quantite_midi));
    setSoir(fmtQty(rappel.quantite_soir));
    setCoucher(fmtQty(rappel.quantite_coucher));
    setDateDebut(rappel.date_debut);
    setDateFin(rappel.date_fin ?? '');
    setNotes(rappel.notes ?? '');
  }, [rappel]);

  const patchMutation = $api.useMutation('patch', '/v1/rappels/{id}', {
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ['get', '/v1/officines/{officineId}/rappels'],
      });
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/prises/today'] });
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/prises'] });
      onOpenChange(false);
    },
  });

  function handleSubmit(e: React.SyntheticEvent) {
    e.preventDefault();
    if (!dateDebut) return;

    patchMutation.mutate({
      params: { path: { id: rappel.id } },
      body: {
        unite: unite.trim() || rappel.unite,
        quantite_matin: parseQty(matin),
        quantite_midi: parseQty(midi),
        quantite_soir: parseQty(soir),
        quantite_coucher: parseQty(coucher),
        date_debut: dateDebut,
        date_fin: dateFin.trim() === '' ? null : dateFin,
        notes: notes.trim() === '' ? null : notes.trim(),
      },
    });
  }

  function handleOpenChange(next: boolean) {
    if (!next) {
      patchMutation.reset();
    }
    onOpenChange(next);
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Modifier le rappel</DialogTitle>
          <DialogDescription>{rappel.nom_texte}</DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Unité */}
          <div className="space-y-2">
            <Label htmlFor="unite">Unité</Label>
            <Input
              id="unite"
              value={unite}
              onChange={(e) => {
                setUnite(e.target.value);
              }}
              placeholder="comprimé, ml, …"
              maxLength={32}
            />
          </div>

          {/* Quantités par moment */}
          <fieldset className="space-y-2">
            <legend className="text-sm font-medium">Quantités par moment (vide = désactivé)</legend>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label htmlFor="matin">Matin</Label>
                <Input
                  id="matin"
                  type="number"
                  min={0}
                  step="any"
                  inputMode="decimal"
                  value={matin}
                  onChange={(e) => {
                    setMatin(e.target.value);
                  }}
                  placeholder="—"
                />
              </div>
              <div className="space-y-1">
                <Label htmlFor="midi">Midi</Label>
                <Input
                  id="midi"
                  type="number"
                  min={0}
                  step="any"
                  inputMode="decimal"
                  value={midi}
                  onChange={(e) => {
                    setMidi(e.target.value);
                  }}
                  placeholder="—"
                />
              </div>
              <div className="space-y-1">
                <Label htmlFor="soir">Soir</Label>
                <Input
                  id="soir"
                  type="number"
                  min={0}
                  step="any"
                  inputMode="decimal"
                  value={soir}
                  onChange={(e) => {
                    setSoir(e.target.value);
                  }}
                  placeholder="—"
                />
              </div>
              <div className="space-y-1">
                <Label htmlFor="coucher">Coucher</Label>
                <Input
                  id="coucher"
                  type="number"
                  min={0}
                  step="any"
                  inputMode="decimal"
                  value={coucher}
                  onChange={(e) => {
                    setCoucher(e.target.value);
                  }}
                  placeholder="—"
                />
              </div>
            </div>
          </fieldset>

          {/* Période */}
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label htmlFor="date-debut">Début *</Label>
              <Input
                id="date-debut"
                type="date"
                value={dateDebut}
                onChange={(e) => {
                  setDateDebut(e.target.value);
                }}
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="date-fin">Fin (optionnel)</Label>
              <Input
                id="date-fin"
                type="date"
                value={dateFin}
                onChange={(e) => {
                  setDateFin(e.target.value);
                }}
              />
            </div>
          </div>

          {/* Notes */}
          <div className="space-y-2">
            <Label htmlFor="notes">Notes</Label>
            <textarea
              id="notes"
              value={notes}
              onChange={(e) => {
                setNotes(e.target.value);
              }}
              placeholder="Avec un grand verre d'eau, …"
              maxLength={2000}
              rows={3}
              className="w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring resize-none"
            />
          </div>

          {patchMutation.error && (
            <p className="text-sm text-destructive">
              Impossible d&apos;enregistrer (l&apos;API a refusé). Réessaie.
            </p>
          )}

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => {
                handleOpenChange(false);
              }}
            >
              Annuler
            </Button>
            <Button type="submit" disabled={patchMutation.isPending || !dateDebut}>
              {patchMutation.isPending ? 'Enregistrement…' : 'Enregistrer'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
