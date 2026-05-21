// Config Playwright pour les E2E web (#141).
//
// Lance `next dev` en webServer, attend qu'il réponde, puis exécute
// les specs sous e2e/. Auth en mode "verification email désactivée"
// (PILOO_DISABLE_EMAIL_VERIFICATION=1) — sinon il faudrait orchestrer
// le magic link, hors scope ici.
//
// Important : les tests assument que DATABASE_URL pointe sur une DB
// dédiée jetable (test ou local dev). Ne PAS lancer contre la prod.
import { defineConfig, devices } from '@playwright/test';

const BASE_URL = process.env['PLAYWRIGHT_BASE_URL'] ?? 'http://localhost:3100';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  retries: process.env['CI'] ? 1 : 0,
  workers: 1,
  reporter: process.env['CI'] ? [['github'], ['list']] : 'list',
  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: {
    // Port 3100 pour ne pas collisionner avec un `pnpm dev` ouvert.
    command: 'pnpm next dev -p 3100',
    url: BASE_URL,
    reuseExistingServer: !process.env['CI'],
    timeout: 120_000,
    env: {
      PILOO_DISABLE_EMAIL_VERIFICATION: '1',
      NEXT_PUBLIC_APP_URL: BASE_URL,
      BETTER_AUTH_URL: BASE_URL,
    },
  },
});
