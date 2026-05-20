// Parser BDPM (#75).
//
// La Base de Données Publique des Médicaments est diffusée par data.gouv.fr
// sous forme de plusieurs fichiers TSV. Pour notre table miroir
// `medicaments_bdpm` on a besoin de 2 fichiers seulement :
//
//   CIS_bdpm.txt           → un médicament par ligne (CIS = identifiant)
//   CIS_CIP_bdpm.txt       → présentations (code CIP) liées à un CIS
//
// Spec officielle des colonnes :
//   https://base-donnees-publique.medicaments.gouv.fr/telechargement.php
//
// Encodage historique : Latin-1. BDPM est passée à UTF-8 depuis 2023, mais
// on tolère les deux pour ne pas casser sur de vieux dumps.
//
// Ce module est PUR (aucun accès DB ni I/O réseau) → testable.

export interface BdpmCis {
  cis: string;
  denomination: string;
  forme: string | null;
  voiesAdministration: string | null;
  statutAmm: string | null;
  titulaire: string | null;
}

export interface BdpmCip {
  cis: string;
  cip7: string | null;
  cip13: string | null;
  tauxRemboursement: number | null;
}

/// Parse `CIS_bdpm.txt` (un médicament par ligne).
/// Colonnes : CIS, dénomination, forme, voies, statut AMM, type AMM,
///            état commercialisation, date AMM, statut BDM commercialisation,
///            n° autorisation européenne, titulaire, surveillance renforcée.
export function parseCisLine(line: string): BdpmCis | null {
  const cols = line.split('\t');
  if (cols.length < 11) return null;
  const cis = cols[0]?.trim();
  const denomination = cols[1]?.trim();
  if (!cis || !denomination) return null;
  return {
    cis,
    denomination,
    forme: nullIfEmpty(cols[2]),
    voiesAdministration: nullIfEmpty(cols[3]),
    statutAmm: nullIfEmpty(cols[4]),
    // colonne 11 (index 10) = titulaire(s)
    titulaire: nullIfEmpty(cols[10]),
  };
}

/// Parse `CIS_CIP_bdpm.txt` (une présentation par ligne).
/// Colonnes : CIS, CIP7, libellé, statut, état, date déclaration,
///            CIP13, agrément collectivités, taux remboursement,
///            prix médicament, prix total, indications.
export function parseCipLine(line: string): BdpmCip | null {
  const cols = line.split('\t');
  if (cols.length < 9) return null;
  const cis = cols[0]?.trim();
  if (!cis) return null;
  return {
    cis,
    cip7: nullIfEmpty(cols[1]),
    cip13: nullIfEmpty(cols[6]),
    // Le taux est noté "65%", "30%", "100%", "non remb." etc.
    tauxRemboursement: parseTaux(cols[8]),
  };
}

/// Stream-parse un fichier TSV ligne par ligne. Filtre les lignes vides
/// et les lignes qui ne matchent pas le parseur fourni. Limite mémoire :
/// O(1), même sur les ~60k lignes de CIS_CIP.
export function* parseTsv<T>(content: string, parser: (line: string) => T | null): Generator<T> {
  // BDPM utilise CRLF sur certains exports historiques.
  const lines = content.split(/\r?\n/);
  for (const raw of lines) {
    if (raw.length === 0) continue;
    const parsed = parser(raw);
    if (parsed !== null) yield parsed;
  }
}

/// Combine les CIS et leurs CIP en lignes prêtes à insérer dans
/// `medicaments_bdpm`. **1 ligne par CIP13** : un médicament (CIS) a
/// 1 à N présentations (tailles de boîte), chacune avec son propre
/// CIP13. La PK est CIP13 — voir packages/db-schema/src/schema/bdpm.ts.
///
/// Les CIPs orphelins (CIS non trouvé dans le CIS_bdpm) sont skip :
/// sans dénomination on ne peut pas afficher l'info au user.
/// Les CIS sans aucun CIP commercialisé sont skip aussi (rare, mais
/// possible pour les AMM toutes neuves sans présentation rattachée).
export function combine(
  cisItems: Iterable<BdpmCis>,
  cipItems: Iterable<BdpmCip>,
  versionBdpm: string,
): MedicamentBdpmRow[] {
  const cisById = new Map<string, BdpmCis>();
  for (const cis of cisItems) cisById.set(cis.cis, cis);

  const seenCip13 = new Set<string>();
  const out: MedicamentBdpmRow[] = [];
  for (const cip of cipItems) {
    if (cip.cip13 === null) continue;
    if (seenCip13.has(cip.cip13)) continue;
    const cisItem = cisById.get(cip.cis);
    if (!cisItem) continue;
    seenCip13.add(cip.cip13);
    out.push({
      cip13: cip.cip13,
      cip7: cip.cip7,
      cis: cisItem.cis,
      denomination: cisItem.denomination,
      forme: cisItem.forme,
      dosage: extractDosage(cisItem.denomination),
      voieAdministration: cisItem.voiesAdministration,
      titulaire: cisItem.titulaire,
      statutAmm: cisItem.statutAmm,
      tauxRemboursement: cip.tauxRemboursement,
      versionBdpm,
    });
  }
  return out;
}

/// Format prêt à insérer dans Drizzle (snake_case côté DB, camelCase en TS).
export interface MedicamentBdpmRow {
  cip13: string;
  cip7: string | null;
  cis: string;
  denomination: string;
  forme: string | null;
  dosage: string | null;
  voieAdministration: string | null;
  titulaire: string | null;
  statutAmm: string | null;
  tauxRemboursement: number | null;
  versionBdpm: string;
}

// --- helpers ---

function nullIfEmpty(v: string | undefined): string | null {
  if (v === undefined) return null;
  const t = v.trim();
  return t.length === 0 ? null : t;
}

function parseTaux(v: string | undefined): number | null {
  if (v === undefined) return null;
  const t = v.trim();
  if (t.length === 0) return null;
  // Format observé : "65%", "30 %", "100%", "non remb.", "" (médicament hors AMM).
  const match = /^(\d{1,3})\s*%/.exec(t);
  if (match?.[1] === undefined) return null;
  const n = Number.parseInt(match[1], 10);
  if (Number.isNaN(n) || n < 0 || n > 100) return null;
  return n;
}

/// Extrait un dosage "1000 mg", "5 mg/ml" depuis une dénomination type
/// "DOLIPRANE 1000 mg, comprimé pelliculé". Best-effort — si rien ne
/// matche on retourne null et l'app affichera juste le `denomination`.
const DOSAGE_REGEX =
  /\b(\d+(?:[,.]\d+)?)\s*(mg|g|µg|ml|UI|%)(?:\/\s*(?:m?l|comprimé|gélule|dose))?/i;

export function extractDosage(denomination: string): string | null {
  const m = DOSAGE_REGEX.exec(denomination);
  if (!m) return null;
  // Conserve la forme texte d'origine (avec virgule ou point).
  return m[0].replace(/\s+/g, ' ').trim();
}
