// Storybook 8 + Vite config (#57).
//
// Pourquoi Vite et pas Next : Storybook avec Vite est ~5× plus rapide
// au dev et au build, et nos composants ui/ ne dépendent d'aucune
// feature spécifique Next (Server Components, etc.). Les composants
// "app" qui consomment $api / next/navigation n'ont pas de stories.
import type { StorybookConfig } from '@storybook/react-vite';
import path from 'node:path';
import url from 'node:url';

const dirname = path.dirname(url.fileURLToPath(import.meta.url));

const config: StorybookConfig = {
  stories: ['../components/ui/**/__stories__/*.stories.@(ts|tsx)'],
  addons: ['@storybook/addon-essentials'],
  framework: {
    name: '@storybook/react-vite',
    options: {},
  },
  typescript: {
    // Storybook a un parser TSX qui plante parfois sur les inférences
    // génériques — on désactive le docgen, les types restent vérifiés
    // par `pnpm typecheck`.
    check: false,
    reactDocgen: false,
  },
  // Le composant ui/label.tsx importe `@/lib/utils` (cn helper) — on
  // recrée l'alias '@' du tsconfig pour que Vite résolve.
  viteFinal(viteConfig) {
    const aliasArray: { find: string; replacement: string }[] = [
      { find: '@', replacement: path.resolve(dirname, '..') },
    ];
    viteConfig.resolve ??= {};
    viteConfig.resolve.alias = aliasArray;
    return viteConfig;
  },
};

export default config;
