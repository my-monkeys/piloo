// Pipeline de génération de résumés IA pour les médicaments (#165).
//
// Pour chaque ligne `medicaments_bdpm` sans `ai_summary`, appelle
// l'API Google Gemini avec un prompt structuré pour produire 2-3 phrases
// "à quoi ça sert + précaution générale". Idempotent : on re-run le
// script à volonté, il skip les lignes déjà enrichies avec la version
// courante.
//
// Coût (gemini-2.5-flash, ~150 input + 80 output tokens par appel) :
//   - 21k médocs × 150 tokens input = 3.15M tokens → ~$0.24
//   - 21k médocs × 80 tokens output = 1.68M tokens → ~$0.50
//   - Total ≈ $0.75
//
// Le script est resumable : si l'API hit un rate limit, on relance et
// il reprend où il s'est arrêté.
//
// Garanties produit :
//   - Le résumé n'est PAS une recommandation clinique (cf. CLAUDE.md
//     racine §"Ce que l'app n'est PAS"). C'est un aide-mémoire.
//   - Le prompt demande explicitement d'éviter posologies et CI.
//   - L'UI affiche "Résumé généré automatiquement · à vérifier auprès
//     d'un professionnel" (déjà présent dans medicament_info_screen).
import { GoogleGenAI } from '@google/genai';
import { medicamentsBdpm, type Db } from '@piloo/db-schema';
import { and, eq, isNull, isNotNull, or, ne, sql } from 'drizzle-orm';

import { log } from '@/lib/server/logger';

const CURRENT_VERSION = 'gemini-2.5-flash/v1';
const MODEL = 'gemini-2.5-flash';

const SYSTEM_PROMPT = `Tu génères des résumés très courts (2 phrases max) de
médicaments à destination du grand public dans une app de suivi de
prises personnelles (Piloo).

Règles strictes :
- 2 phrases courtes, ton neutre et factuel.
- 1ère phrase : à quoi ça sert (catégorie thérapeutique + indication
  principale).
- 2e phrase : éventuel point d'attention général (sans poser de
  contre-indication précise — c'est le rôle du médecin).
- AUCUNE posologie, AUCUN dosage, AUCUNE durée de traitement.
- AUCUNE contre-indication précise (allergies, grossesse, etc.).
- AUCUNE recommandation de prise (à jeun, avec repas, etc.).
- Pas de marque commerciale — décris la molécule.
- Pas de jargon médical inutile.
- Réponds UNIQUEMENT le texte du résumé, sans préambule ni guillemets.

Exemple sortie :
"Antalgique et antipyrétique utilisé pour soulager les douleurs légères à modérées et faire baisser la fièvre. À utiliser uniquement sur prescription ou avis d'un professionnel de santé."`;

export interface SummaryGenInput {
  cip13: string;
  denomination: string;
  dosage: string | null;
  forme: string | null;
}

export interface SummaryGenResult {
  scanned: number;
  generated: number;
  skipped: number;
  failures: number;
  durationMs: number;
  /// Tokens cumulés sur tous les appels Gemini réussis (input prompt).
  inputTokens: number;
  /// Tokens cumulés sur tous les appels Gemini réussis (output text).
  outputTokens: number;
  /// Coût USD estimé sur la passe (cf. PRICING_USD ci-dessous).
  estimatedCostUsd: number;
  /// Coût moyen par génération réussie (USD). null si 0 généré.
  avgCostPerGenerationUsd: number | null;
}

/// Prix Gemini officiels (USD / 1M tokens), 2026-05 — voir
/// https://ai.google.dev/pricing. À mettre à jour si on change MODEL
/// ou si Google révise les tarifs.
const PRICING_USD = {
  inputPerMillion: 0.3, // gemini-2.5-flash input
  outputPerMillion: 2.5, // gemini-2.5-flash output
};

export interface SummaryGenOptions {
  /// Limite de médicaments traités dans cette passe. null = tout.
  limit?: number;
  /// Pause entre 2 appels API (ms) pour respecter les rate limits.
  /// Gemini Flash : 1000 RPM par défaut → 60ms suffisent ; on prend
  /// 150ms pour de la marge.
  throttleMs?: number;
  /// API key (par défaut GEMINI_API_KEY ou GOOGLE_API_KEY de l'env).
  apiKey?: string;
}

export async function runSummaryGeneration(
  db: Db,
  opts: SummaryGenOptions = {},
): Promise<SummaryGenResult> {
  const t0 = Date.now();
  const apiKey = opts.apiKey ?? process.env['GEMINI_API_KEY'] ?? process.env['GOOGLE_API_KEY'];
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY (ou GOOGLE_API_KEY) non défini');
  }

  const client = new GoogleGenAI({ apiKey });
  const throttleMs = opts.throttleMs ?? 150;

  // Médicaments à traiter : ai_summary null OU ai_summary_version != current.
  // Permet de retraiter quand on bump le prompt (CURRENT_VERSION).
  const baseQuery = db
    .select({
      cip13: medicamentsBdpm.cip13,
      denomination: medicamentsBdpm.denomination,
      dosage: medicamentsBdpm.dosage,
      forme: medicamentsBdpm.forme,
    })
    .from(medicamentsBdpm)
    .where(
      or(
        isNull(medicamentsBdpm.aiSummary),
        and(
          isNotNull(medicamentsBdpm.aiSummaryVersion),
          ne(medicamentsBdpm.aiSummaryVersion, CURRENT_VERSION),
        ),
      ),
    );
  const todo = await (opts.limit ? baseQuery.limit(opts.limit) : baseQuery);

  let generated = 0;
  let failures = 0;
  let inputTokens = 0;
  let outputTokens = 0;
  for (const row of todo) {
    try {
      const { summary, usage } = await generateOne(client, row);
      await db
        .update(medicamentsBdpm)
        .set({ aiSummary: summary, aiSummaryVersion: CURRENT_VERSION })
        .where(eq(medicamentsBdpm.cip13, row.cip13));
      generated++;
      inputTokens += usage.inputTokens;
      outputTokens += usage.outputTokens;
    } catch (e) {
      failures++;
      // On log mais on continue — un médoc qui plante le LLM ne doit
      // pas faire échouer toute la passe.
      log.warn('bdpm.ai_summary.failed', {
        cip13: row.cip13,
        message: e instanceof Error ? e.message : String(e),
      });
    }
    if (throttleMs > 0) {
      await new Promise((r) => setTimeout(r, throttleMs));
    }
  }

  const estimatedCostUsd = computeCostUsd(inputTokens, outputTokens);

  return {
    scanned: todo.length,
    generated,
    skipped: todo.length - generated - failures,
    failures,
    durationMs: Date.now() - t0,
    inputTokens,
    outputTokens,
    estimatedCostUsd: round6(estimatedCostUsd),
    avgCostPerGenerationUsd: generated > 0 ? round6(estimatedCostUsd / generated) : null,
  };
}

function round6(n: number): number {
  return Math.round(n * 1_000_000) / 1_000_000;
}

/// Calcul de coût USD à partir des tokens consommés. Exportée pour
/// les tests + l'UI admin qui veut estimer le coût avant lancement.
export function computeCostUsd(inputTokens: number, outputTokens: number): number {
  return (
    (inputTokens / 1_000_000) * PRICING_USD.inputPerMillion +
    (outputTokens / 1_000_000) * PRICING_USD.outputPerMillion
  );
}

interface GenerateOneResult {
  summary: string;
  usage: { inputTokens: number; outputTokens: number };
}

async function generateOne(client: GoogleGenAI, row: SummaryGenInput): Promise<GenerateOneResult> {
  const userMsg = `Médicament : ${row.denomination}${row.dosage ? ` (${row.dosage})` : ''}${row.forme ? ` — ${row.forme}` : ''}`;
  const res = await client.models.generateContent({
    model: MODEL,
    contents: userMsg,
    config: {
      systemInstruction: SYSTEM_PROMPT,
      // Gemini 2.5 consomme des tokens en thinking par défaut. Pour un
      // résumé de 2 phrases, on désactive le thinking — sinon il bouffe
      // le budget et la réponse sort tronquée.
      thinkingConfig: { thinkingBudget: 0 },
      maxOutputTokens: 300,
      // temperature basse pour des résumés stables/reproductibles.
      temperature: 0.3,
    },
  });
  const text = (res.text ?? '').trim();
  if (text.length === 0) {
    throw new Error('Réponse Gemini vide');
  }
  const inputTokens = res.usageMetadata?.promptTokenCount ?? 0;
  const outputTokens = res.usageMetadata?.candidatesTokenCount ?? 0;
  return {
    summary: text,
    usage: { inputTokens, outputTokens },
  };
}

/// Export pour les tests + l'UI admin (#166) qui veut afficher le tarif
/// utilisé sans avoir à le hardcoder.
export const SUMMARY_PRICING_USD = PRICING_USD;

/// Count des médicaments restant à traiter (ai_summary null ou version
/// périmée). Utile pour le monitoring et l'UI admin (#166).
export async function countPendingSummaries(db: Db): Promise<number> {
  const [row] = await db
    .select({ n: sql<number>`count(*)::int` })
    .from(medicamentsBdpm)
    .where(
      or(
        isNull(medicamentsBdpm.aiSummary),
        and(
          isNotNull(medicamentsBdpm.aiSummaryVersion),
          ne(medicamentsBdpm.aiSummaryVersion, CURRENT_VERSION),
        ),
      ),
    );
  return row?.n ?? 0;
}
