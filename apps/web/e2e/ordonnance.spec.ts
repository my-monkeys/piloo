// E2E ordonnances — scénario #3 du ticket #141.
//
// Crée une ordonnance via le dialog (saisie texte libre, pas besoin de
// BDPM seedé) et vérifie qu'elle apparaît dans la table.
import { expect, test } from '@playwright/test';

import { dismissCookieBanner, makeTestUser } from './helpers';

test('create ordonnance puis affichage en liste', async ({ page }) => {
  const user = makeTestUser('ord');

  // Mock BDPM pour retourner zéro résultat (évite que le composant
  // affiche un loading state interminable si le endpoint n'existe pas
  // côté test).
  await page.route('**/api/v1/bdpm/search**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ items: [] }),
    });
  });

  // 1. Sign-up
  await page.goto('/sign-up');
  await dismissCookieBanner(page);
  await page.getByLabel(/prénom/i).fill(user.prenom);
  await page.getByLabel(/nom/i).fill(user.nom);
  await page.getByLabel(/email/i).fill(user.email);
  await page.getByLabel(/mot de passe/i).fill(user.password);
  await page.getByRole('button', { name: /créer mon compte/i }).click();
  await page.waitForURL(/\/dashboard/, { timeout: 15_000 });

  // 2. Activer l'officine perso auto-créée.
  await page.goto('/settings/officines');
  await page
    .getByRole('button', { name: /^activer$/i })
    .first()
    .click();

  // 3. Aller sur ordonnances + ouvrir le dialog.
  await page.goto('/ordonnances');
  await page.getByRole('button', { name: /nouvelle ordonnance/i }).click();

  // 4. Remplir : date (pré-remplie aujourd'hui) + prescripteur + médicament.
  await page.getByLabel(/prescripteur/i).fill('Dr E2E');
  // Le champ "Médicament *" du dialog (différent du champ inventory).
  await page.getByLabel('Médicament *').fill('Doliprane test (E2E)');

  // 5. Submit.
  await page
    .getByRole('button', { name: /enregistrer|créer/i })
    .first()
    .click();

  // 6. Dialog fermé + ordonnance dans la table.
  await expect(page.getByRole('dialog')).toBeHidden({ timeout: 5_000 });
  await expect(page.getByText('Dr E2E')).toBeVisible({ timeout: 5_000 });
});
