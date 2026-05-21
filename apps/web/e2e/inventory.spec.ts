// E2E inventory — scénario #2 du ticket #141 ("scan simulé").
//
// On simule un scan en POSTant directement la boîte via l'API (le scan
// mobile = juste un raccourci pour le même POST). Puis on vérifie qu'elle
// apparaît dans la table /inventory. La recherche BDPM en UI est testée
// séparément dans add-boite-dialog.test.tsx — pas l'objet ici.
import { expect, test } from '@playwright/test';

import { activateFirstOfficine, makeTestUser, signUpViaUi } from './helpers';

test('add boîte via API (scan simulé) + visible dans /inventory', async ({ page, context }) => {
  const user = makeTestUser('inv');

  // 1. Sign-up + activate officine perso
  await signUpViaUi(page, user);
  const officineId = await activateFirstOfficine(context, page);

  // 2. POST boîte via API (équivalent au scan mobile qui POST aussi).
  const cip13 = '3400930007777';
  const create = await page.request.post(`/api/v1/officines/${officineId}/boites`, {
    data: {
      cip13,
      peremption: '2027-06-30',
      unites_restantes: 20,
      lot: 'E2E-LOT-001',
    },
  });
  expect(create.status(), `create boîte response: ${await create.text()}`).toBe(201);

  // 3. Navigue sur l'inventaire et vérifie que la boîte apparaît.
  await page.goto('/inventory');
  await expect(page.getByText(cip13)).toBeVisible({ timeout: 10_000 });
});
