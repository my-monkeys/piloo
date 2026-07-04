// Tailwind 3 + shadcn pour Piloo (#56).
//
// Couleurs : on mappe les CSS vars `--piloo-color-*` (générées depuis
// `packages/design-tokens/tokens.json`) sur les classes Tailwind. Les
// conventions shadcn (`bg-background`, `text-foreground`, etc.) sont
// gardées pour pouvoir installer les blocks de la registry shadcn sans
// renommage. Les classes spécifiques Piloo (`bg-piloo-primary`,
// `text-piloo-accent`) cohabitent — on les utilisera pour les nuances
// brand qui ne mappent pas sur le couple foreground/background standard.
import type { Config } from 'tailwindcss';
import animate from 'tailwindcss-animate';

const config: Config = {
  darkMode: ['class'],
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}', './lib/**/*.{ts,tsx}'],
  theme: {
    container: {
      center: true,
      padding: '1rem',
      screens: { '2xl': '1280px' },
    },
    extend: {
      colors: {
        // Mapping shadcn (sémantique) — alimenté par tokens Piloo.
        border: 'var(--piloo-color-border)',
        input: 'var(--piloo-color-border)',
        ring: 'var(--piloo-color-primary)',
        background: 'var(--piloo-color-background)',
        foreground: 'var(--piloo-color-text-primary)',
        primary: {
          DEFAULT: 'var(--piloo-color-primary)',
          foreground: 'var(--piloo-color-text-on-primary)',
        },
        secondary: {
          DEFAULT: 'var(--piloo-color-surface-subtle)',
          foreground: 'var(--piloo-color-text-secondary)',
        },
        destructive: {
          DEFAULT: 'var(--piloo-color-error-on)',
          foreground: 'var(--piloo-color-error)',
        },
        muted: {
          DEFAULT: 'var(--piloo-color-surface-subtle)',
          foreground: 'var(--piloo-color-text-tertiary)',
        },
        accent: {
          DEFAULT: 'var(--piloo-color-accent)',
          foreground: 'var(--piloo-color-text-on-primary)',
        },
        popover: {
          DEFAULT: 'var(--piloo-color-surface)',
          foreground: 'var(--piloo-color-text-primary)',
        },
        card: {
          DEFAULT: 'var(--piloo-color-surface)',
          foreground: 'var(--piloo-color-text-primary)',
        },
        // Namespace Piloo direct — pour les couleurs hors-mapping shadcn.
        piloo: {
          background: 'var(--piloo-color-background)',
          surface: 'var(--piloo-color-surface)',
          surfaceSubtle: 'var(--piloo-color-surface-subtle)',
          primary: 'var(--piloo-color-primary)',
          'primary-hover': 'var(--piloo-color-primary-hover)',
          'primary-soft': 'var(--piloo-color-primary-soft)',
          accent: 'var(--piloo-color-accent)',
          'accent-soft': 'var(--piloo-color-accent-soft)',
          success: 'var(--piloo-color-success)',
          'success-on': 'var(--piloo-color-success-on)',
          warning: 'var(--piloo-color-warning)',
          'warning-on': 'var(--piloo-color-warning-on)',
          error: 'var(--piloo-color-error)',
          'error-on': 'var(--piloo-color-error-on)',
        },
      },
      borderRadius: {
        sm: '6px',
        md: '8px',
        lg: '12px',
        xl: '16px',
        '2xl': '20px',
        full: '9999px',
      },
      fontFamily: {
        // Fraunces (titres, cohérent avec le mobile), Manrope (UI), Spline
        // Sans Mono (codes techniques : CIP13, lot, n° série). Chargées via
        // next/font dans le root layout, exposées en CSS vars.
        display: ['var(--font-display)', '"Fraunces"', 'Georgia', 'serif'],
        sans: [
          'var(--font-sans)',
          '"Manrope"',
          '-apple-system',
          'BlinkMacSystemFont',
          'sans-serif',
        ],
        mono: ['var(--font-mono)', '"Spline Sans Mono"', 'ui-monospace', 'monospace'],
      },
      keyframes: {
        'accordion-down': {
          from: { height: '0' },
          to: { height: 'var(--radix-accordion-content-height)' },
        },
        'accordion-up': {
          from: { height: 'var(--radix-accordion-content-height)' },
          to: { height: '0' },
        },
      },
      animation: {
        'accordion-down': 'accordion-down 0.2s ease-out',
        'accordion-up': 'accordion-up 0.2s ease-out',
      },
    },
  },
  plugins: [animate],
};

export default config;
