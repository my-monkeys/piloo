// Helpers partagés entre les specs E2E (#141).
import { type Page, type APIRequestContext, type BrowserContext } from '@playwright/test';

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
  await page.getByLabel('Email', { exact: true }).fill(user.email);
  await page.getByLabel('Mot de passe', { exact: true }).fill(user.password);
  await page.getByRole('button', { name: /se connecter/i }).click();
  await page.waitForURL(/\/dashboard/, { timeout: 15_000 });
}

/** Helper sign-up via UI — factorise le boilerplate des 3 specs. */
export async function signUpViaUi(page: Page, user: TestUser): Promise<void> {
  await page.goto('/sign-up');
  await dismissCookieBanner(page);
  await page.getByLabel('Prénom', { exact: true }).fill(user.prenom);
  await page.getByLabel('Nom', { exact: true }).fill(user.nom);
  await page.getByLabel('Email', { exact: true }).fill(user.email);
  await page.getByLabel('Mot de passe', { exact: true }).fill(user.password);
  await page.getByRole('button', { name: /créer mon compte/i }).click();
  await page.waitForURL(/\/dashboard/, { timeout: 15_000 });
}

/** Récupère la première officine de l'user authentifié et fixe le cookie
 *  `piloo_active_officine` pour que les pages /inventory et /ordonnances
 *  affichent la table au lieu de "Aucune officine sélectionnée".
 *
 *  Pose le cookie au niveau context Playwright (visible avant tout render
 *  côté React) ET via document.cookie (au cas où). */
export async function activateFirstOfficine(context: BrowserContext, page: Page): Promise<string> {
  const res = await page.request.get('/api/v1/officines');
  if (!res.ok()) throw new Error(`GET /v1/officines failed: ${String(res.status())}`);
  const body = (await res.json()) as { items?: { id: string }[] };
  const first = body.items?.[0];
  if (!first)
    throw new Error('Aucune officine retournée par /v1/officines (hook auto-create cassé ?)');
  const url = new URL(page.url());
  await context.addCookies([
    {
      name: 'piloo_active_officine',
      value: first.id,
      domain: url.hostname,
      path: '/',
      sameSite: 'Lax',
      expires: Math.floor(Date.now() / 1000) + 86400,
    },
  ]);
  await page.evaluate((id) => {
    document.cookie = `piloo_active_officine=${id}; path=/; max-age=31536000; samesite=lax`;
  }, first.id);
  return first.id;
}
