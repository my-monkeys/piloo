// Page préférences cookies (#160). Détaille les catégories et permet
// à l'utilisateur de modifier son choix à tout moment.
//
// Versionnée comme les autres pages légales (cf. #173 — pattern
// `VERSION` constant).
'use client';

import { useEffect, useState } from 'react';

import { Button } from '@/components/ui/button';
import { useCookieConsent } from '@/lib/cookies/consent';

const VERSION = '2026-05-17';

export default function CookiesPreferencesPage() {
  const { consent, setConsent } = useCookieConsent();
  const [analytics, setAnalytics] = useState(consent?.analytics ?? false);
  const [saved, setSaved] = useState(false);

  // Sync local form state avec le consentement persisté quand il change.
  useEffect(() => {
    setAnalytics(consent?.analytics ?? false);
  }, [consent]);

  function save() {
    setConsent({ analytics });
    setSaved(true);
    setTimeout(() => {
      setSaved(false);
    }, 2000);
  }

  return (
    <article>
      <p className="legal-version">Version : {VERSION}</p>
      <h1>Préférences cookies</h1>

      <p>
        Piloo limite volontairement l&apos;usage de cookies. Pas de tracking tiers, pas
        d&apos;analytics commercial. Tu peux modifier ton choix à tout moment depuis cette page.
      </p>

      <h2>Cookies utilisés</h2>

      <Category
        title="Strictement nécessaires"
        required
        description={
          <>
            Cookies de session Better Auth (<code>better-auth.session_token</code>) : permettent de
            rester connecté. Sans eux, il faudrait se reconnecter à chaque page.{' '}
            <strong>Exemptés de consentement</strong> selon l&apos;article 5(3) de la directive
            ePrivacy.
          </>
        }
      />

      <Category
        title="Fonctionnels"
        required
        description={
          <>
            <code>piloo_active_officine</code> : mémorise quelle officine est active dans la
            sidebar. <code>piloo_cookie_consent</code> : mémorise ce choix-ci. Sans ces cookies,
            l&apos;app reste utilisable mais l&apos;expérience est dégradée.
          </>
        }
      />

      <Category
        title="Analytics"
        checked={analytics}
        onChange={setAnalytics}
        description={
          <>
            <em>Pas activé actuellement.</em> Si un jour Piloo ajoute une mesure d&apos;audience
            (Plausible self-hosted ou équivalent privacy-first), elle sera derrière cet opt-in.
            Aucun outil tiers commercial (Google Analytics, Mixpanel, Hotjar…) ne sera jamais
            utilisé sur les écrans avec données médicales.
          </>
        }
      />

      <div style={{ marginTop: '1.5em', display: 'flex', gap: '0.75em', alignItems: 'center' }}>
        <Button onClick={save}>Enregistrer mes préférences</Button>
        {saved && (
          <span style={{ fontSize: '0.875rem', color: 'var(--piloo-color-text-secondary)' }}>
            ✓ Enregistré
          </span>
        )}
      </div>

      <p
        style={{
          marginTop: '2em',
          fontSize: '0.875rem',
          color: 'var(--piloo-color-text-tertiary)',
        }}
      >
        {consent
          ? `Dernier choix enregistré : ${new Date(consent.decidedAt).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })}.`
          : "Aucun choix enregistré pour l'instant — accepte ou refuse via le bandeau."}
      </p>
    </article>
  );
}

function Category({
  title,
  description,
  required,
  checked,
  onChange,
}: {
  title: string;
  description: React.ReactNode;
  required?: boolean;
  checked?: boolean;
  onChange?: (v: boolean) => void;
}) {
  return (
    <section
      style={{
        margin: '1.25em 0',
        padding: '1em',
        border: '1px solid var(--piloo-color-border)',
        borderRadius: 8,
      }}
    >
      <header
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '0.5em',
        }}
      >
        <h3 style={{ margin: 0 }}>{title}</h3>
        {required ? (
          <span
            style={{
              fontSize: '0.75rem',
              color: 'var(--piloo-color-text-tertiary)',
              textTransform: 'uppercase',
              letterSpacing: 0.5,
            }}
          >
            Toujours actif
          </span>
        ) : (
          <label
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.5em',
              fontSize: '0.875rem',
              cursor: 'pointer',
            }}
          >
            <input
              type="checkbox"
              checked={checked ?? false}
              onChange={(e) => {
                onChange?.(e.target.checked);
              }}
              style={{ width: 16, height: 16 }}
            />
            <span>{checked ? 'Activé' : 'Désactivé'}</span>
          </label>
        )}
      </header>
      <p style={{ margin: 0, fontSize: '0.95rem' }}>{description}</p>
    </section>
  );
}
