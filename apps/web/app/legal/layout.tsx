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
        padding: '32px 20px 64px',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
        color: '#1a1a1a',
        lineHeight: 1.6,
      }}
    >
      {children}
    </main>
  );
}
