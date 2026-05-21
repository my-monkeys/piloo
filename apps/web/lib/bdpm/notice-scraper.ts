// Scraper de la notice ANSM (#non-ticket, suite remontée user).
//
// Récupère les sections textuelles du RCP (Résumé des Caractéristiques
// Produit) depuis la base-donnees-publique.medicaments.gouv.fr. Le
// contenu est public (open data ministère), on relaie tel quel avec
// attribution — pas de transformation/résumé pour rester hors MDR.
//
// Sections ciblées (les plus utiles pour un usage perso) :
//   4.1 Indications thérapeutiques
//   4.2 Posologie et mode d'administration
//   4.3 Contre-indications
//   4.4 Mises en garde spéciales et précautions d'emploi
//   4.5 Interactions médicamenteuses
//   4.6 Grossesse et allaitement
//   4.8 Effets indésirables
//
// Robustesse : si une section manque (page différente, refonte ANSM),
// on la renvoie absente plutôt que de tout faire planter. L'UI mobile
// décide quoi afficher.
import * as cheerio from 'cheerio';
import type { AnyNode } from 'domhandler';

import { log } from '@/lib/server/logger';

export interface NoticeSection {
  /** Numéro de section RCP (ex: "4.1"). Sert d'ID stable côté front. */
  number: string;
  /** Titre brut tel qu'imprimé par l'ANSM. */
  title: string;
  /** Contenu texte (paragraphes joints par double newline). */
  text: string;
}

export interface BdpmNotice {
  /** CIS du médicament (clé d'origine). */
  cis: string;
  /** URL canonique vers la page ANSM. */
  sourceUrl: string;
  /** ISO timestamp du scrape. */
  scrapedAt: string;
  /** Sections triées par numéro. Peut être vide si la page est introuvable. */
  sections: NoticeSection[];
}

const BASE_URL = 'http://base-donnees-publique.medicaments.gouv.fr/medicament';
const USER_AGENT = 'PilooBot/1.0 (+https://piloo.fr/contact)';

/// Sections RCP qui ont une valeur utilisateur. On exclut les sections
/// admin (1-3, 5+), trop techniques pour le grand public.
const TARGET_SECTIONS = new Set(['4.1', '4.2', '4.3', '4.4', '4.5', '4.6', '4.7', '4.8', '4.9']);

export async function scrapeNoticeFromAnsm(cis: string): Promise<BdpmNotice> {
  const sourceUrl = `${BASE_URL}/${encodeURIComponent(cis)}/extrait`;
  const res = await fetch(sourceUrl, {
    headers: { 'User-Agent': USER_AGENT, Accept: 'text/html' },
    redirect: 'follow',
  });
  if (!res.ok) {
    log.warn('notice_scraper.http_failed', { cis, status: res.status });
    return {
      cis,
      sourceUrl,
      scrapedAt: new Date().toISOString(),
      sections: [],
    };
  }
  const html = await res.text();
  const sections = parseSections(html);
  return {
    cis,
    sourceUrl,
    scrapedAt: new Date().toISOString(),
    sections,
  };
}

/// Extrait les sections RCP du HTML ANSM. Approche défensive :
///   1. Cherche les `<p class="AmmAnnexeTitre2">` qui commencent par
///      "4.X." (titres de section). C'est l'invariant ANSM le plus
///      stable — présent même quand l'ancre id/name manque (cas 4.1).
///   2. Pour chaque header, on remonte le `<p>` racine (les sous-balises
///      `<span id=...>` sont à l'intérieur), puis on collecte les
///      siblings jusqu'au prochain titre de section (4.X ou 5+).
///   3. Nettoie : whitespace collapse, retire "Retour en haut de page",
///      strip ancres internes type "_Hlk...".
export function parseSections(html: string): NoticeSection[] {
  const $ = cheerio.load(html);

  const out: NoticeSection[] = [];
  // Tous les <p class="AmmAnnexeTitre2"> + leurs frères "AmmAnnexeTitre1"
  // (sections de niveau supérieur 4, 5, 6…) : ce sont les frontières.
  const allTitres = $('p.AmmAnnexeTitre1, p.AmmAnnexeTitre2').toArray();

  // Filtre uniquement les 4.X qui nous intéressent. On garde l'index
  // dans `allTitres` pour pouvoir trouver le prochain header (peu importe
  // s'il est 4.X ou 5+) comme borne de fin.
  const targets: { index: number; number: string; title: string }[] = [];
  for (let i = 0; i < allTitres.length; i++) {
    const el = allTitres[i];
    if (!el) continue;
    const raw = $(el).text().replace(/\s+/g, ' ').trim();
    const number = extractSectionNumber(raw);
    if (number === null || !TARGET_SECTIONS.has(number)) continue;
    targets.push({ index: i, number, title: raw });
  }

  for (const t of targets) {
    const header = allTitres[t.index];
    if (!header) continue;
    const nextHeader = allTitres[t.index + 1] ?? null;
    const text = collectTextBetween($, header, nextHeader);
    if (text.trim().length === 0) continue;
    out.push({ number: t.number, title: t.title, text });
  }

  out.sort((a, b) => a.number.localeCompare(b.number, undefined, { numeric: true }));
  return out;
}

/// Extrait `4.X` depuis un titre type "4.1. Indications thérapeutiques"
/// ou un id type "4.1._Indications_thérapeutiques".
function extractSectionNumber(raw: string): string | null {
  const match = /^(\d+\.\d+)/.exec(raw.trim());
  return match?.[1] ?? null;
}

/// Collecte le texte des nodes entre `from` (exclusif) et `to` (exclusif),
/// au sein du même parent. Le contenu ANSM est généralement structuré en
/// frères directs d'une div racine.
function collectTextBetween($: cheerio.CheerioAPI, from: AnyNode, to: AnyNode | null): string {
  const chunks: string[] = [];
  let current = from.nextSibling;
  while (current && current !== to) {
    const type: string = current.type;
    if (type === 'tag') {
      const $el = $(current);
      // Ignore les liens "retour en haut" et tooltips associés (bruit pur).
      const className = $el.attr('class') ?? '';
      if (className.includes('lien-retour-hautdepage') || className.includes('fr-tooltip')) {
        current = current.nextSibling;
        continue;
      }
      const text = $el.text();
      const cleaned = text
        .replace(/Retour en haut de page/g, '')
        .replace(/Redirection vers le haut de page/g, '')
        .replace(/\s+\n/g, '\n')
        .replace(/[ \t]+/g, ' ')
        .replace(/\n{3,}/g, '\n\n')
        .trim();
      if (cleaned.length > 0) chunks.push(cleaned);
    } else if (type === 'text') {
      const data = (current as unknown as { data: string }).data;
      const cleaned = data.replace(/\s+/g, ' ').trim();
      if (cleaned.length > 0) chunks.push(cleaned);
    }
    current = current.nextSibling;
  }
  return chunks.join('\n\n').trim();
}
