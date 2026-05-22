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
  /// Libellé brut "plaquette PVC-aluminium de 8 comprimés".
  libellePresentation: string | null;
  tauxRemboursement: number | null;
}

/// Présentation parsée depuis le libellé BDPM. Sert à adapter les
/// wordings UI ("8 comprimés" vs "200 ml" vs "30 g") sans concaténer
/// du texte ad-hoc côté mobile.
export interface ParsedPresentation {
  /// "boîte" | "flacon" | "tube" | "ampoule" | "sachet" | …
  /// Note : on traduit "plaquette" → "boîte" car c'est l'unité que
  /// l'utilisateur achète/manipule (la plaquette est dans la boîte).
  container: string | null;
  /// Quantité totale de doses dans le conditionnement complet
  /// (ex: 20 récipients de 2 ml → 40 ml ; 20 plaquettes de 14 cp → 280 cp).
  totalDoses: number | null;
  /// Mot dose au singulier ("comprimé", "ml", "g", "ampoule"…).
  doseUnit: string | null;
  /// Variante au pluriel quand applicable ("comprimés", "ampoules") ;
  /// identique au singulier pour les unités invariantes (ml, g).
  doseUnitPlural: string | null;
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
    libellePresentation: nullIfEmpty(cols[2]),
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
    const pres = cip.libellePresentation ? parsePresentation(cip.libellePresentation) : null;
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
      libellePresentation: cip.libellePresentation,
      container: pres?.container ?? null,
      totalDoses: pres?.totalDoses ?? null,
      doseUnit: pres?.doseUnit ?? null,
      doseUnitPlural: pres?.doseUnitPlural ?? null,
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
  libellePresentation: string | null;
  container: string | null;
  totalDoses: number | null;
  doseUnit: string | null;
  doseUnitPlural: string | null;
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

/// Heuristique sur les libellés BDPM (`libelle_presentation`).
///
/// Exemples couverts :
///   "plaquette PVC-aluminium de 8 comprimés"         → boîte / 8  / comprimé
///   "flacon en verre de 200 ml"                       → flacon / 200 / ml
///   "tube aluminium de 30 g"                          → tube / 30 / g
///   "1 inhalateur de 200 doses"                       → inhalateur / 200 / dose
///   "20 ampoule en verre de 5 ml"                     → ampoule / 100 / ml
///   "20 récipient unidose de 2 ml"                    → récipient / 40 / ml
///   "20 plaquette PVC aluminium de 14 comprimés"      → boîte / 280 / comprimé
///
/// Règles :
/// 1. Container = premier mot trouvé dans CONTAINERS (plaquette traduit
///    en "boîte" car c'est ce que l'user achète).
/// 2. Total doses = produit (prefix_count × "de N <unit>" count) ;
///    fallback à un seul si l'autre manque.
/// 3. Unit = celle du `de N <unit>` ; sinon le container lui-même.
export function parsePresentation(libelle: string): ParsedPresentation {
  const s = libelle.toLowerCase();

  // 1) Container ----------------------------------------------------
  // Priorité aux mots les plus spécifiques (inhalateur > flacon, etc.)
  // car certaines présentations contiennent plusieurs mots.
  const CONTAINER_MAP: { match: string; label: string }[] = [
    { match: 'inhalateur', label: 'inhalateur' },
    { match: 'pulvérisateur', label: 'pulvérisateur' },
    { match: 'aérosol', label: 'aérosol' },
    { match: 'pilulier', label: 'pilulier' },
    { match: 'seringue', label: 'seringue' },
    { match: 'stylo', label: 'stylo' },
    { match: 'cartouche', label: 'cartouche' },
    { match: 'ampoule', label: 'ampoule' },
    { match: 'sachet', label: 'sachet' },
    { match: 'récipient', label: 'récipient' },
    { match: 'flacon', label: 'flacon' },
    { match: 'tube', label: 'tube' },
    { match: 'pot', label: 'pot' },
    { match: 'poche', label: 'poche' },
    { match: 'plaquette', label: 'boîte' }, // user-friendly
  ];
  let container: string | null = null;
  for (const { match, label } of CONTAINER_MAP) {
    if (s.includes(match)) {
      container = label;
      break;
    }
  }

  // 2) Préfixe numérique en début de ligne (ex: "20 récipient ..."). --
  // Match juste les chiffres + espace puis n'importe quoi.
  const prefixMatch = /^(\d+)\s+\S/.exec(s);
  const prefixCount = prefixMatch?.[1] ? Number.parseInt(prefixMatch[1], 10) : null;

  // 3) "de N <unit>" — on prend la DERNIÈRE occurrence pour gérer les
  //    libellés multi-étages ("plaquette de 5 récipients de 2 ml").
  // \b en JS utilise [A-Za-z0-9_] (ASCII), donc il "voit" une frontière
  // entre `m` et `é` dans "comprimés" → mauvais matching. On utilise un
  // look-ahead négatif qui rejette toute lettre (accentuée incluse) qui
  // suit, ce qui force le match à aller jusqu'au vrai mot complet.
  const LETTER = '[a-zéèàùâêîôûç]';
  const re = new RegExp(`de\\s+(\\d+(?:[.,]\\d+)?)\\s+(${LETTER}+?)s?(?!${LETTER})`, 'g');
  const deMatches = [...s.matchAll(re)];
  const last = deMatches[deMatches.length - 1];
  let perUnit: number | null = null;
  let unitWord: string | null = null;
  if (last?.[1] && last[2]) {
    perUnit = Number.parseFloat(last[1].replace(',', '.'));
    unitWord = last[2];
  }

  // 4) Compose le total : prefix × per (ou l'un des deux seul).
  let totalDoses: number | null = null;
  if (prefixCount !== null && perUnit !== null) {
    totalDoses = Math.round(prefixCount * perUnit);
  } else if (perUnit !== null) {
    totalDoses = Math.round(perUnit);
  } else if (prefixCount !== null) {
    totalDoses = prefixCount;
  }

  // 5) Unit choisie : celle du "de N <unit>" ; sinon le container.
  //    Pour les unités invariables (ml/g/mg/UI) on garde tel quel.
  let doseUnit: string | null = unitWord;
  if (doseUnit === null && container !== null) doseUnit = container;
  // Normalisation singulier (le parser a déjà retiré le 's' final).
  // Cas mots irréguliers : "comprimés" → "comprimé" déjà OK ; mais
  // "doses" → "dose", "ampoules" → "ampoule" : déjà OK.

  const INVARIANT_UNITS = new Set(['ml', 'g', 'mg', 'µg', 'l', 'cl', 'ui']);
  const doseUnitPlural =
    doseUnit === null ? null : INVARIANT_UNITS.has(doseUnit) ? doseUnit : `${doseUnit}s`;

  return {
    container,
    totalDoses,
    doseUnit,
    doseUnitPlural,
  };
}
