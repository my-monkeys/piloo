// Preview des icônes Phosphor pour le mapping forme BDPM → icône (#98).
// Pas d'auth, pas de fetch : juste un static visuel pour valider le
// choix d'icônes avec l'user avant d'appliquer côté mobile.
//
// Les SVG viennent du CDN GitHub raw — c'est exactement le rendu que
// Phosphor produit côté Flutter (mêmes glyphes).
import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Preview icônes médicaments — Piloo' };

interface Famille {
  label: string;
  icon: string; // nom Phosphor kebab-case sans suffixe -fill
  formes: string[];
}

const FAMILLES: Famille[] = [
  {
    label: 'Comprimé + Gélule (solides ingérables)',
    icon: 'pill',
    formes: [
      'comprimé',
      'comprimé pelliculé',
      'comprimé sécable',
      'comprimé gastro-résistant',
      'gélule',
      'gélule gastro-résistant',
      'capsule molle',
      'suppositoire',
      'ovule',
      'dispositif',
    ],
  },
  {
    label: 'Injection / Perfusion',
    icon: 'syringe',
    formes: [
      'solution injectable',
      'solution pour perfusion',
      'poudre pour solution injectable',
      'solution à diluer pour perfusion',
    ],
  },
  {
    label: 'Sirop / Buvable',
    icon: 'flask',
    formes: ['sirop', 'solution buvable', 'suspension buvable', 'poudre pour suspension buvable'],
  },
  {
    label: 'Crème / Gel / Pommade',
    icon: 'hand-soap',
    formes: ['crème', 'gel', 'pommade', 'solution pour application'],
  },
  {
    label: 'Inhalation',
    icon: 'wind',
    formes: ['gaz pour inhalation', 'aérosol', 'poudre pour inhalation'],
  },
  {
    label: 'Collyre / Gouttes',
    icon: 'eyedropper',
    formes: ['collyre en solution', 'gouttes oculaires', 'gouttes nasales', 'gouttes auriculaires'],
  },
  {
    label: 'Patch / Transdermique',
    icon: 'bandaids',
    formes: ['dispositif transdermique', 'patch'],
  },
  {
    label: 'Spray / Pulvérisation',
    icon: 'rocket-launch',
    formes: ['solution pour pulvérisation nasale', 'spray buccal'],
  },
];

const CDN = (icon: string) =>
  `https://raw.githubusercontent.com/phosphor-icons/core/main/assets/fill/${icon}-fill.svg`;

export default function Page() {
  return (
    <div
      style={{
        minHeight: '100vh',
        background: '#FAF6EE',
        padding: '40px 20px',
        fontFamily: 'system-ui, -apple-system, sans-serif',
        color: '#2A2520',
      }}
    >
      <div style={{ maxWidth: 880, margin: '0 auto' }}>
        <h1 style={{ fontFamily: 'serif', fontSize: 32, fontWeight: 500, margin: '0 0 8px' }}>
          Icônes par forme de médicament
        </h1>
        <p style={{ color: '#6F6859', fontSize: 14, marginTop: 0, marginBottom: 32 }}>
          Preview du mapping Phosphor pour Piloo mobile. Chaque famille agrège plusieurs formes BDPM
          proches.
        </p>

        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))',
            gap: 16,
          }}
        >
          {FAMILLES.map((f) => (
            <div
              key={f.icon}
              style={{
                background: '#FFFFFF',
                border: '1px solid #E8E1D2',
                borderRadius: 16,
                padding: 20,
                display: 'flex',
                flexDirection: 'column',
                gap: 12,
              }}
            >
              <div
                style={{
                  width: 56,
                  height: 56,
                  borderRadius: 28,
                  background: '#F3EDE1',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <img
                  src={CDN(f.icon)}
                  alt={f.label}
                  width={28}
                  height={28}
                  style={{ filter: 'invert(15%)' }}
                />
              </div>
              <div>
                <div style={{ fontSize: 15, fontWeight: 600 }}>{f.label}</div>
                <div
                  style={{ fontSize: 11, color: '#8B8475', marginTop: 4, fontFamily: 'monospace' }}
                >
                  {f.icon}
                </div>
              </div>
              <ul
                style={{
                  fontSize: 12,
                  color: '#6F6859',
                  margin: 0,
                  paddingLeft: 16,
                  lineHeight: 1.6,
                }}
              >
                {f.formes.map((forme) => (
                  <li key={forme}>{forme}</li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
