// Auto-link rétroactif des boîtes orphelines à BDPM (#55).
//
// Au scan, si BDPM ne reconnaît pas le CIP, la boîte est créée avec
// `notes = 'CIP <cip13>'` (préfixe convention). Quand BDPM est mis à
// jour (cron mensuel `/api/cron/import-bdpm`), certains de ces CIPs
// peuvent maintenant matcher → on retente le lookup et on remplace le
// préfixe par le vrai nom du médicament.
//
// Convention notes (cf. apps/mobile boîte_add_screen) :
//   "NOM_PRÉFIX // notes libres"
// Le préfix avant " // " est traité comme le nom affiché. Pour les
// boîtes orphelines on a `notes = 'CIP <cip13>'` (avec ou sans suffixe
// " // ..." si l'user avait écrit des notes en plus).
//
// On ne touche QUE les boîtes orphelines (préfixe "CIP ") — pas les
// boîtes renommées manuellement par l'utilisateur via QuickAction.rename.
import { boites, medicamentsBdpm, type Db } from '@piloo/db-schema';
import { and, eq, ilike, isNull } from 'drizzle-orm';

export interface AutoLinkResult {
  scanned: number;
  relinked: number;
  durationMs: number;
}

export async function runBdpmAutoLink(db: Db): Promise<AutoLinkResult> {
  const t0 = Date.now();

  // Toutes les boîtes actives dont les notes commencent par "CIP "
  // (= jamais résolues à BDPM). On exclut les soft-deleted.
  const orphans = await db
    .select({
      id: boites.id,
      cip13: boites.cip13,
      notes: boites.notes,
    })
    .from(boites)
    .where(
      and(
        isNull(boites.deletedAt),
        // Avec ou sans suffixe " // notes libres" — on couvre les deux
        // cas avec ILIKE.
        ilike(boites.notes, 'CIP %'),
      ),
    );

  let relinked = 0;
  for (const orphan of orphans) {
    const [med] = await db
      .select({ denomination: medicamentsBdpm.denomination })
      .from(medicamentsBdpm)
      .where(eq(medicamentsBdpm.cip13, orphan.cip13))
      .limit(1);
    if (!med) continue;

    // Sépare le préfixe "CIP <cip13>" du reste pour préserver les
    // notes libres de l'utilisateur.
    const rest = extractRestNotes(orphan.notes);
    const newNotes =
      rest === null || rest.length === 0 ? med.denomination : `${med.denomination} // ${rest}`;

    await db
      .update(boites)
      .set({ notes: newNotes, updatedAt: new Date() })
      .where(eq(boites.id, orphan.id));
    relinked++;
  }

  return {
    scanned: orphans.length,
    relinked,
    durationMs: Date.now() - t0,
  };
}

/// Extrait les notes libres après le séparateur " // " (s'il existe).
/// Retourne null si pas de séparateur (= rien après le préfix CIP).
function extractRestNotes(notes: string | null): string | null {
  if (notes === null) return null;
  const idx = notes.indexOf(' // ');
  if (idx < 0) return null;
  return notes.substring(idx + 4);
}

// Re-export interne pour les tests unitaires.
export const __testing = { extractRestNotes };
