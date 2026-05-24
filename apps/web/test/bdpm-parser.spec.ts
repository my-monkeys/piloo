// Tests parser BDPM (#75).
//
// On utilise des extraits réalistes des fichiers BDPM officiels (5-10
// lignes chacun) pour vérifier que la chaîne complète parse → combine
// produit les bonnes lignes prêtes à insérer.
import { describe, expect, it } from 'vitest';

import { combine, extractDosage, parseCipLine, parseCisLine, parseTsv } from '@/lib/bdpm/parser';

// Extraits réels (anonymisés sur les titulaires non commerciaux).
// Format : champs séparés par tabulation, dans l'ordre officiel BDPM.
const CIS_FIXTURE = [
  '60002283\tDOLIPRANE 1000 mg, comprimé pelliculé\tcomprimé pelliculé\torale\tAutorisation active\tProcédure nationale\tCommercialisée\t01/01/1995\t\t\tSANOFI AVENTIS FRANCE\tNon',
  '64014219\tDAFALGAN 500 mg, gélule\tgélule\torale\tAutorisation active\tProcédure nationale\tCommercialisée\t15/06/1998\t\t\tUPSA\tNon',
  '60404439\tKARDEGIC 75 mg, poudre pour solution buvable en sachet-dose\tpoudre\torale\tAutorisation active\tProcédure nationale\tCommercialisée\t01/01/1990\t\t\tSANOFI AVENTIS FRANCE\tNon',
  '69603847\tHUMEX RHUME, comprimé et solution buvable\tcomprimé\torale\tAutorisation active\tProcédure nationale\tCommercialisée\t01/01/2010\t\t\tURGO HEALTHCARE\tNon',
  '\tLigne malformée sans CIS\t', // doit être ignorée
].join('\n');

const CIP_FIXTURE = [
  '60002283\t3400934567890\tplaquette(s) PVC PVDC aluminium de 8 comprimé(s)\tPrésentation active\tDéclaration de commercialisation\t01/01/1995\t3400934567890\toui\t65%\t2,18\t2,18\t',
  '60002283\t3400934567891\tplaquette(s) PVC PVDC aluminium de 16 comprimé(s)\tPrésentation active\tDéclaration de commercialisation\t01/01/1995\t3400934567891\toui\t65%\t3,50\t3,50\t',
  '64014219\t3400935123456\tplaquette(s) thermoformée(s) PVC aluminium de 16 gélule(s)\tPrésentation active\tDéclaration de commercialisation\t15/06/1998\t3400935123456\toui\t65%\t1,80\t1,80\t',
  '60404439\t3400938765432\t30 sachet(s)\tPrésentation active\tDéclaration de commercialisation\t01/01/1990\t3400938765432\toui\t30%\t4,90\t4,90\t',
  '69603847\t3400990001234\tboîte de 16\tPrésentation active\tDéclaration de commercialisation\t01/01/2010\t3400990001234\tnon\tnon remb.\t6,90\t6,90\t',
].join('\n');

describe('parseCisLine', () => {
  it("extrait les 6 champs utiles d'une ligne CIS", () => {
    const line =
      '60002283\tDOLIPRANE 1000 mg, comprimé pelliculé\tcomprimé pelliculé\torale\tAutorisation active\tProcédure nationale\tCommercialisée\t01/01/1995\t\t\tSANOFI AVENTIS FRANCE\tNon';
    expect(parseCisLine(line)).toEqual({
      cis: '60002283',
      denomination: 'DOLIPRANE 1000 mg, comprimé pelliculé',
      forme: 'comprimé pelliculé',
      voiesAdministration: 'orale',
      statutAmm: 'Autorisation active',
      titulaire: 'SANOFI AVENTIS FRANCE',
    });
  });

  it('retourne null si moins de 11 colonnes', () => {
    expect(parseCisLine('60002283\tDOLIPRANE\tcomprimé')).toBeNull();
  });

  it('retourne null si CIS ou dénomination vide', () => {
    expect(parseCisLine('\tLigne malformée\t\t\t\t\t\t\t\t\tEditeur\t')).toBeNull();
  });
});

describe('parseCipLine', () => {
  it('extrait CIS, CIP7, CIP13, taux remboursement', () => {
    const line =
      '60002283\t3400934567890\tplaquette(s) PVC PVDC aluminium de 8 comprimé(s)\tPrésentation active\tDéclaration de commercialisation\t01/01/1995\t3400934567890\toui\t65%\t2,18\t2,18\t';
    expect(parseCipLine(line)).toEqual({
      cis: '60002283',
      cip7: '3400934567890', // BDPM met le CIP13 à la place du CIP7 dans certaines lignes ; ici col 1 = code historique
      cip13: '3400934567890',
      libellePresentation: 'plaquette(s) PVC PVDC aluminium de 8 comprimé(s)',
      tauxRemboursement: 65,
    });
  });

  it('parse "non remb." comme null', () => {
    const line =
      '69603847\t3400990001234\tboîte de 16\tPrésentation active\tDéclaration de commercialisation\t01/01/2010\t3400990001234\tnon\tnon remb.\t6,90\t6,90\t';
    expect(parseCipLine(line)?.tauxRemboursement).toBeNull();
  });

  it('retourne null si moins de 9 colonnes', () => {
    expect(parseCipLine('60002283\t3400934567890\tlibelle')).toBeNull();
  });
});

describe('parseTsv (streaming)', () => {
  it('parse plusieurs lignes en yieldant les valides', () => {
    const lines = [...parseTsv(CIS_FIXTURE, parseCisLine)];
    expect(lines).toHaveLength(4); // la 5e ligne est malformée et ignorée
    expect(lines[0]?.cis).toBe('60002283');
    expect(lines[3]?.cis).toBe('69603847');
  });

  it('tolère les fins de ligne CRLF', () => {
    const cr = CIS_FIXTURE.replace(/\n/g, '\r\n');
    const lines = [...parseTsv(cr, parseCisLine)];
    expect(lines).toHaveLength(4);
  });
});

describe('combine', () => {
  it('émet une ligne par CIP13 — Doliprane a 2 présentations', () => {
    const cisItems = [...parseTsv(CIS_FIXTURE, parseCisLine)];
    const cipItems = [...parseTsv(CIP_FIXTURE, parseCipLine)];
    const rows = combine(cisItems, cipItems, '2026-05-01');
    expect(rows).toHaveLength(5);
    const doliprane = rows.filter((r) => r.cis === '60002283');
    expect(doliprane).toHaveLength(2);
    expect(doliprane.map((r) => r.cip13).sort()).toEqual(['3400934567890', '3400934567891']);
    // La dénomination est partagée par les deux présentations.
    expect(doliprane[0]).toMatchObject({
      cis: '60002283',
      denomination: 'DOLIPRANE 1000 mg, comprimé pelliculé',
      forme: 'comprimé pelliculé',
      dosage: '1000 mg',
      voieAdministration: 'orale',
      titulaire: 'SANOFI AVENTIS FRANCE',
      statutAmm: 'Autorisation active',
      tauxRemboursement: 65,
      versionBdpm: '2026-05-01',
    });
  });

  it('aucune ligne émise si aucun CIP rattaché — les CIS sans présentation sont skip', () => {
    const cis = [...parseTsv(CIS_FIXTURE, parseCisLine)];
    const rows = combine(cis, [], '2026-05-01');
    expect(rows).toHaveLength(0);
  });

  it('un médicament non remboursé sort taux=null mais ligne créée', () => {
    const cisItems = [...parseTsv(CIS_FIXTURE, parseCisLine)];
    const cipItems = [...parseTsv(CIP_FIXTURE, parseCipLine)];
    const rows = combine(cisItems, cipItems, '2026-05-01');
    const humex = rows.find((r) => r.cis === '69603847')!;
    expect(humex.tauxRemboursement).toBeNull();
    expect(humex.cip13).toBe('3400990001234');
  });
});

describe('extractDosage', () => {
  it('extrait "1000 mg" depuis "DOLIPRANE 1000 mg, comprimé pelliculé"', () => {
    expect(extractDosage('DOLIPRANE 1000 mg, comprimé pelliculé')).toBe('1000 mg');
  });

  it('extrait "75 mg" depuis "KARDEGIC 75 mg, poudre…"', () => {
    expect(extractDosage('KARDEGIC 75 mg, poudre pour solution buvable en sachet-dose')).toBe(
      '75 mg',
    );
  });

  it('extrait "5 mg/ml" pour les sirops', () => {
    expect(extractDosage('IBUPROFENE 5 mg/ml suspension buvable')).toBe('5 mg/ml');
  });

  it('retourne null si rien ne matche', () => {
    expect(extractDosage('HUMEX RHUME, comprimé et solution buvable')).toBeNull();
  });

  it('gère la virgule décimale française "0,5 mg"', () => {
    expect(extractDosage('LEVOTHYROX 0,5 mg, comprimé')).toBe('0,5 mg');
  });
});
