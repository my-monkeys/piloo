// Tests du template + mailer alerte critique (#134).
//
// Tests unitaires purs (pas de DB) : on couvre le rendu HTML/texte pour
// chaque type d'alerte + le helper sendAlerteEmail mocké.
import { describe, expect, it, vi } from 'vitest';

import { renderAlerteCritique } from '@/lib/email/templates/alerte-critique';

vi.mock('@/lib/email/client', () => ({
  sendEmail: vi.fn(() => Promise.resolve({ ok: true, stubbed: false })),
}));

describe('renderAlerteCritique', () => {
  it('rend une alerte péremption 7j avec titre + détail', () => {
    const out = renderAlerteCritique({
      type: 'peremption_7j',
      prenom: 'Maxime',
      officineNom: 'Maison',
      medicament: 'Doliprane 1000mg',
      detail: 'Périme le 27/05/2026',
      ctaUrl: 'https://piloo.fr/inventory#boite-1',
    });
    expect(out.subject).toContain('Péremption imminente');
    expect(out.subject).toContain('Doliprane');
    expect(out.subject).toContain('Maison');
    expect(out.html).toContain('Doliprane');
    expect(out.html).toContain('Périme le 27/05/2026');
    expect(out.html).toContain('https://piloo.fr/inventory#boite-1');
    expect(out.text).toContain('Périme le 27/05/2026');
  });

  it('rend une alerte stock_bas avec CTA "Voir le médicament"', () => {
    const out = renderAlerteCritique({
      type: 'stock_bas',
      officineNom: 'Cabinet Dubois',
      medicament: 'Levothyrox 50µg',
      detail: 'Reste 2 doses',
      ctaUrl: 'https://piloo.fr/dashboard',
    });
    expect(out.subject).toContain('Stock bas');
    expect(out.html).toContain('Voir le médicament');
    expect(out.html).toContain('Reste 2 doses');
  });

  it('couvre les 5 types sans crash + texte non vide', () => {
    const types = [
      'peremption_30j',
      'peremption_7j',
      'stock_bas',
      'prise_oubliee',
      'manque_signale',
    ] as const;
    for (const t of types) {
      const out = renderAlerteCritique({
        type: t,
        officineNom: 'Officine',
        medicament: 'Médicament X',
        detail: 'Détail Y',
        ctaUrl: 'https://piloo.fr',
      });
      expect(out.subject.length).toBeGreaterThan(0);
      expect(out.html).toContain('Médicament X');
      expect(out.text).toContain('Médicament X');
    }
  });

  it('échappe le HTML dangereux dans les champs utilisateur', () => {
    const out = renderAlerteCritique({
      type: 'stock_bas',
      officineNom: '<script>alert(1)</script>',
      medicament: "M&M's",
      detail: '"detail"',
      ctaUrl: 'https://piloo.fr',
    });
    expect(out.html).not.toContain('<script>alert(1)</script>');
    expect(out.html).toContain('&lt;script&gt;');
    expect(out.html).toContain('M&amp;M&#39;s');
  });
});

describe('sendAlerteEmail', () => {
  it('appelle sendEmail avec le tag dérivé du type', async () => {
    const { sendEmail } = await import('@/lib/email/client');
    const { sendAlerteEmail } = await import('@/lib/email/alertes-mailer');

    await sendAlerteEmail({
      alerte: {
        type: 'peremption_7j',
        payload: { boite_id: 'b-1' },
        officineId: 'off-1',
      },
      recipient: { email: 'user@piloo.fr', prenom: 'Alice' },
      officineNom: 'Maison',
      appUrl: 'https://piloo.fr',
      hints: { medicament: 'Doliprane', detail: 'Périme dans 5 jours' },
    });

    expect(sendEmail).toHaveBeenCalledWith(
      expect.objectContaining({
        to: 'user@piloo.fr',
        tag: 'alerte:peremption_7j',
        subject: expect.stringContaining('Doliprane'),
      }),
    );
  });
});
