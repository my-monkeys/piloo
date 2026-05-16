// Layout commun aux pages /legal/* (#96, #173). Inline styles tant que
// Tailwind/shadcn n'est pas installé (#56) — les couleurs viennent des
// tokens Piloo via les CSS vars `--piloo-*` (cf. styles/tokens.gen.css
// importé au root layout). Typo responsive via `clamp()`.
import type { ReactNode } from 'react';

export const metadata = {
  title: 'Mentions légales — Piloo',
  description: "Conditions d'utilisation, politique de confidentialité et mentions légales.",
};

export default function LegalLayout({ children }: { children: ReactNode }) {
  return (
    <main
      style={{
        maxWidth: 720,
        margin: '0 auto',
        padding: 'clamp(20px, 4vw, 32px) clamp(16px, 4vw, 24px) 64px',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
        color: 'var(--piloo-color-text-primary, #1a1a1a)',
        backgroundColor: 'var(--piloo-color-background, #fff)',
        // Typographie responsive : 15-17px selon viewport, line-height aéré.
        fontSize: 'clamp(15px, 0.95rem + 0.1vw, 17px)',
        lineHeight: 1.65,
        // Marges propres entre les headings — applied via :first-child resets.
      }}
    >
      <style>{`
        main h1 { font-size: clamp(1.6rem, 1.4rem + 1vw, 2rem); margin: 0 0 0.5em; line-height: 1.2; }
        main h2 { font-size: clamp(1.1rem, 1rem + 0.4vw, 1.3rem); margin: 2em 0 0.5em; line-height: 1.3; }
        main h3 { font-size: 1.05rem; margin: 1.5em 0 0.4em; line-height: 1.35; }
        main p { margin: 0 0 1em; }
        main ul { padding-left: 1.25em; margin: 0 0 1em; }
        main li { margin: 0.25em 0; }
        main a { color: var(--piloo-color-primary, #4a6b64); }
        main a:hover { color: var(--piloo-color-primary-hover, #3d5a54); }
        main code {
          background: var(--piloo-color-surface-subtle, #f1ede2);
          padding: 0.1em 0.3em;
          border-radius: 3px;
          font-size: 0.9em;
        }
        main .legal-version {
          font-size: 0.8125rem;
          color: var(--piloo-color-text-tertiary, #9ca3af);
          margin-bottom: 0.5em;
        }
      `}</style>
      {children}
    </main>
  );
}
