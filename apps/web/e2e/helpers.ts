// Helpers partagés entre les specs E2E (#141).
import { type Page, type APIRequestContext } from '@playwright/test';

export interface TestUser {
  email: string;
  password: string;
  name: string;
  nom: string;
  prenom: string;
  typeCompte: 'particulier' | 'pro';
}

export function makeTestUser(suffix?: string): TestUser {
  const ts = Date.now().toString(36);
  const rand = Math.random().toString(36).slice(2, 8);
  const slug = suffix ? `${suffix}-${rand}` : rand;
  return {
    email: `e2e-${slug}-${ts}@piloo.fr`,
    password: 'test-pass-1234',
    name: 'E2E User',
    nom: 'User',
    prenom: 'E2E',
    typeCompte: 'particulier',
  };
}

/** Sign-up via API direct — bypass UI pour des tests qui assument déjà
 *  un user authentifié (inventory/ordonnance). Utilise un APIRequestContext
 *  séparé pour ne pas polluer le storage state du navigateur. */
export async function signUpViaApi(request: APIRequestContext, user: TestUser): Promise<void> {
  const res = await request.post('/api/auth/sign-up/email', { data: user });
  if (!res.ok()) {
    throw new Error(`signUpViaApi failed: ${String(res.status())} ${await res.text()}`);
  }
}

/** Dismiss le cookie banner (présent en bas sur premier render) pour
 *  que les clicks ne soient pas interceptés. */
export async function dismissCookieBanner(page: Page): Promise<void> {
  const accept = page.getByRole('button', { name: /tout accepter|accepter tout/i });
  if (await accept.isVisible().catch(() => false)) {
    await accept.click();
  }
}

/** Sign-in UI — assume que requireEmailVerification est désactivé
 *  (cf. playwright.config.ts env PILOO_DISABLE_EMAIL_VERIFICATION=1). */
export async function signInViaUi(page: Page, user: TestUser): Promise<void> {
  await page.goto('/sign-in');
  await dismissCookieBanner(page);
  await page.getByLabel(/email/i).fill(user.email);
  await page.getByLabel(/mot de passe/i).fill(user.password);
  await page.getByRole('button', { name: /se connecter/i }).click();
  await page.waitForURL(/\/dashboard/, { timeout: 15_000 });
}
