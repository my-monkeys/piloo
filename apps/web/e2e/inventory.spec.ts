// E2E inventory — scénario #2 du ticket #141 ("scan simulé").
//
// On simule un scan en mockant la recherche BDPM (qui retourne 0 résultat
// sur la DB de test vide) avec un médicament factice. L'utilisateur tape
// dans le champ de recherche, sélectionne le résultat mock, fixe la
// péremption et enregistre. La boîte doit apparaître dans la table.
import { expect, test } from '@playwright/test';

import { activateFirstOfficine, makeTestUser, signUpViaUi } from './helpers';

const FAKE_BDPM = {
  items: [
    {
      cis: '60000777',
      cip13: '3400930007777',
      cip7: '3000777',
      denomination: 'DOLIPRANE 1000mg comprimé (E2E)',
      forme: 'comprimé',
      dosage: '1000mg',
      voie_administration: 'orale',
      titulaire: 'TEST',
      statut_amm: 'Autorisation active',
      taux_remboursement: 65,
      version_bdpm: '2026-05-01',
    },
  ],
};

test('add boîte via dialog (scan simulé via mock BDPM)', async ({ page, context }) => {
  const user = makeTestUser('inv');

  // Mock la recherche BDPM avant toute navigation pour intercepter les
  // requêtes du dialog.
  await page.route('**/api/v1/bdpm/search**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(FAKE_BDPM),
    });
  });

  // 1. Sign-up
  await signUpViaUi(page, user);

  // 2. Activer l'officine perso auto-créée via cookie.
  await activateFirstOfficine(context, page);

  // 3. Aller sur l'inventaire et ouvrir le dialog.
  await page.goto('/inventory');
  await page.getByRole('button', { name: /ajouter une boîte/i }).click();

  // 4. Recherche BDPM (mockée) + sélection du résultat.
  await page.getByLabel('Médicament *', { exact: true }).fill('doli');
  // La debounce est à 250ms côté composant + fetch mocké instantané.
  const result = page.getByRole('button', { name: /DOLIPRANE 1000mg.*\(E2E\)/i });
  await expect(result).toBeVisible({ timeout: 5_000 });
  await result.click();

  // 5. Péremption + submit.
  await page.getByLabel(/^péremption/i).fill('2027-06-30');
  await page.getByRole('button', { name: /enregistrer la boîte/i }).click();

  // 6. Le dialog se ferme + la boîte apparaît dans la table (CIP13).
  await expect(page.getByRole('dialog')).toBeHidden({ timeout: 5_000 });
  await expect(page.getByText('3400930007777')).toBeVisible({ timeout: 5_000 });
});
