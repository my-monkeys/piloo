import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: false,
    environment: 'node',
    include: ['**/*.{test,spec}.{ts,tsx}'],
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
      '**/.next/**',
      '**/.turbo/**',
      '**/build/**',
      '**/out/**',
      '**/coverage/**',
      '**/generated/**',
      'apps/mobile/**',
      // apps/web a son propre vitest.config.ts (alias @/) — laisser
      // `turbo run test` les exécuter via le script local.
      'apps/web/**',
      '.octogent/**',
      '.claude/**',
    ],
    reporters: ['default'],
    passWithNoTests: true,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      reportsDirectory: './coverage',
      include: ['apps/**/src/**', 'packages/**/src/**', 'scripts/**'],
      exclude: [
        '**/node_modules/**',
        '**/*.config.*',
        '**/*.test.*',
        '**/*.spec.*',
        '**/generated/**',
        '**/dist/**',
        '**/build/**',
        'apps/mobile/**',
      ],
    },
  },
});
