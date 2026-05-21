// E2E ordonnances — scénario #3 du ticket #141.
//
// Crée une ordonnance via l'API puis vérifie qu'elle s'affiche dans la
// liste /ordonnances. La création via dialog UI est testée séparément
// dans add-ordonnance-dialog.test.tsx — on focus ici sur le round-trip
// API → page list.
import { expect, test } from '@playwright/test';

import { activateFirstOfficine, makeTestUser, signUpViaUi } from './helpers';

test('create ordonnance via API + affichage en liste', async ({ page, context }) => {
  const user = makeTestUser('ord');

  // 1. Sign-up + activate officine perso
  await signUpViaUi(page, user);
  const officineId = await activateFirstOfficine(context, page);

  // 2. POST ordonnance avec une prescription Doliprane texte libre.
  const today = new Date().toISOString().slice(0, 10);
  const create = await page.request.post(`/api/v1/officines/${officineId}/ordonnances`, {
    data: {
      date_prescription: today,
      prescripteur: 'Dr E2E',
      source: 'manuelle',
      prescriptions: [
        {
          nom_texte: 'Doliprane test (E2E)',
          posologie: {
            unitesParPrise: 1,
            unite: 'comprimé',
            frequence: 'quotidien',
            moments: ['matin'],
          },
        },
      ],
    },
  });
  expect(create.status(), `create ordonnance response: ${await create.text()}`).toBe(201);

  // 3. Navigue sur /ordonnances et vérifie l'affichage.
  await page.goto('/ordonnances');
  await expect(page.getByText('Dr E2E')).toBeVisible({ timeout: 10_000 });
});
