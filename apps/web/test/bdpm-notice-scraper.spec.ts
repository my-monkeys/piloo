// Tests du parser de notice ANSM.
//
// Les tests utilisent un HTML stub minimal qui reproduit la structure
// d'ancres `4.X._...` utilisée par base-donnees-publique.medicaments.gouv.fr.
// Pas de fetch réel ici — le scrapeNoticeFromAnsm est testé séparément
// (manuellement quand l'ANSM est dispo).
import { describe, expect, it } from 'vitest';

import { parseSections } from '@/lib/bdpm/notice-scraper';

// Reproduit la structure réelle d'une page extrait ANSM :
//  - titres niveau 1 (4. DONNEES CLINIQUES, 5. PROPRIETES…) :
//    <p class="AmmAnnexeTitre1">…</p>
//  - titres niveau 2 (4.1, 4.2, …) : <p class="AmmAnnexeTitre2">…</p>
//  - 4.1 n'a généralement PAS d'ancre, juste le texte ; les suivants
//    ont un <span id='4.X._...'> à l'intérieur (qu'on ignore désormais).
const STUB_HTML = `
<html><body>
<p class="AmmAnnexeTitre1">4. DONNEES CLINIQUES</p>
<p class="AmmAnnexeTitre2">4.1. Indications thérapeutiques</p>
<p class="AmmCorpsTexte">Traitement symptomatique des douleurs d'intensité légère à modérée.</p>
<p class="AmmCorpsTexte">Et de la fièvre.</p>
<p class="AmmAnnexeTitre2"><a name="RcpPosoAdmin"><span id='4.2._Posologie_et_mode_d_administration'>4.2. Posologie et mode d'administration</span></a></p>
<p class="AmmCorpsTexte">Adulte : 1 à 2 comprimés, 3 fois par jour. Espacer les prises de 6 heures.</p>
<a class="lien-retour-hautdepage" href="#top">Retour en haut de page</a>
<p class="AmmAnnexeTitre2"><a name="RcpContreIndications"><span id='4.3._Contre-indications'>4.3. Contre-indications</span></a></p>
<ul><li>Hypersensibilité au paracétamol</li><li>Insuffisance hépatique sévère</li></ul>
<p class="AmmAnnexeTitre2"><span id='4.4._Mises_en_garde'>4.4. Mises en garde</span></p>
<p class="AmmCorpsTexte">Ne pas dépasser la dose maximale recommandée.</p>
<p class="AmmAnnexeTitre1">5. PROPRIETES PHARMACOLOGIQUES</p>
<p class="AmmCorpsTexte">Ne devrait PAS apparaître dans les sections retournées (filtre 4.X).</p>
</body></html>
`;

describe('parseSections', () => {
  it('extrait les sections 4.1 à 4.4 depuis le HTML stub', () => {
    const sections = parseSections(STUB_HTML);
    expect(sections).toHaveLength(4);
    expect(sections.map((s) => s.number)).toEqual(['4.1', '4.2', '4.3', '4.4']);
  });

  it('section 4.1 contient le texte des paragraphes (joints)', () => {
    const sections = parseSections(STUB_HTML);
    const indic = sections.find((s) => s.number === '4.1');
    expect(indic?.title).toContain('Indications');
    expect(indic?.text).toContain('Traitement symptomatique');
    expect(indic?.text).toContain('Et de la fièvre');
  });

  it('section 4.2 retire le "Retour en haut de page"', () => {
    const sections = parseSections(STUB_HTML);
    const poso = sections.find((s) => s.number === '4.2');
    expect(poso?.text).not.toContain('Retour en haut');
    expect(poso?.text).toContain('1 à 2 comprimés');
  });

  it("section 4.3 récupère le contenu d'une liste", () => {
    const sections = parseSections(STUB_HTML);
    const ci = sections.find((s) => s.number === '4.3');
    expect(ci?.text).toContain('paracétamol');
    expect(ci?.text).toContain('Insuffisance hépatique');
  });

  it('ignore les sections hors plage 4.X (ex: section 5)', () => {
    const sections = parseSections(STUB_HTML);
    expect(sections.find((s) => s.number.startsWith('5'))).toBeUndefined();
  });

  it('retourne tableau vide si aucune section 4.X présente', () => {
    expect(parseSections('<html><body><p>Pas de section RCP</p></body></html>')).toEqual([]);
  });
});
