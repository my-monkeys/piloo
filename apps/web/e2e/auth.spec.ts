// E2E auth — scénario #1 du ticket #141.
//
// Sign-up via UI puis vérifie l'atterrissage sur /dashboard. La vérif
// email est désactivée en mode E2E (PILOO_DISABLE_EMAIL_VERIFICATION=1)
// donc Better Auth pose directement la session après sign-up.
import { expect, test } from '@playwright/test';

import { dismissCookieBanner, makeTestUser } from './helpers';

test('sign-up → dashboard puis sign-out → sign-in', async ({ page }) => {
  const user = makeTestUser('auth');

  // 1. Sign-up
  await page.goto('/sign-up');
  await dismissCookieBanner(page);
  await page.getByLabel('Prénom', { exact: true }).fill(user.prenom);
  await page.getByLabel('Nom', { exact: true }).fill(user.nom);
  await page.getByLabel('Email', { exact: true }).fill(user.email);
  await page.getByLabel('Mot de passe', { exact: true }).fill(user.password);
  await page.getByRole('button', { name: /créer mon compte/i }).click();
  await page.waitForURL(/\/dashboard/, { timeout: 15_000 });
  await expect(page.getByRole('heading', { name: /tableau de bord/i })).toBeVisible();

  // 2. Sign-out via API puis navigate /sign-in directement (le middleware
  //    de redirect "auth-only" est sur les routes app — on ne le teste pas
  //    ici, on focus sur le round-trip credentials).
  await page.request.post('/api/auth/sign-out');
  await page.goto('/sign-in');

  // 3. Sign-in avec les mêmes credentials.
  await page.getByLabel('Email', { exact: true }).fill(user.email);
  await page.getByLabel('Mot de passe', { exact: true }).fill(user.password);
  await page.getByRole('button', { name: /se connecter/i }).click();
  await page.waitForURL(/\/dashboard/, { timeout: 15_000 });
  await expect(page.getByRole('heading', { name: /tableau de bord/i })).toBeVisible();
});
