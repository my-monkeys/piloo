// Génère les fichiers natifs depuis tokens.json (#51).
//
// Sorties :
//   - apps/mobile/lib/core/theme/colors.dart   (PilooColors)
//   - apps/mobile/lib/core/theme/radius.dart   (PilooRadius)
//   - apps/mobile/lib/core/theme/spacing.dart  (PilooSpacing)
//   - apps/web/styles/tokens.gen.css           (--piloo-* CSS vars)
//
// Usage : `pnpm tokens:build` (depuis la racine ou ce package).
//
// Note : pas de génération de typography.dart (typo Manrope/Fraunces
// est codée à la main dans theme.dart, complexe à exprimer en JSON
// portable). Si on doit en faire un token, ce sera un follow-up.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..', '..');

const tokens = JSON.parse(readFileSync(join(here, '..', 'tokens.json'), 'utf8'));

const HEADER = [
  '// GENERATED — do not edit.',
  '// Source: packages/design-tokens/tokens.json',
  '// Pour modifier les tokens : édite tokens.json puis lance',
  '// `pnpm tokens:build` (depuis la racine du repo).',
].join('\n');

function toDartHex(hex) {
  // "#RRGGBB" → "0xFFRRGGBB" (alpha 100%)
  if (!/^#[0-9A-Fa-f]{6}$/.test(hex)) {
    throw new Error(`Couleur invalide (attendu #RRGGBB) : ${hex}`);
  }
  return `0xFF${hex.slice(1).toUpperCase()}`;
}

function generateColorsDart() {
  const lines = [
    HEADER,
    '',
    "import 'package:flutter/material.dart';",
    '',
    'abstract class PilooColors {',
  ];
  for (const [name, hex] of Object.entries(tokens.colors)) {
    lines.push(`  static const Color ${name} = Color(${toDartHex(hex)});`);
  }
  lines.push('}', '');
  return lines.join('\n');
}

function generateRadiusDart() {
  const lines = [HEADER, '', 'abstract class PilooRadius {'];
  for (const [name, value] of Object.entries(tokens.radius)) {
    lines.push(`  static const double ${name} = ${value};`);
  }
  lines.push('}', '');
  return lines.join('\n');
}

function generateSpacingDart() {
  const lines = [HEADER, '', 'abstract class PilooSpacing {'];
  for (const [name, value] of Object.entries(tokens.spacing)) {
    lines.push(`  static const double ${name} = ${value};`);
  }
  lines.push('}', '');
  return lines.join('\n');
}

function kebab(name) {
  return name.replace(/([A-Z])/g, '-$1').toLowerCase();
}

function generateCss() {
  const lines = [
    '/* GENERATED — do not edit.',
    ' * Source: packages/design-tokens/tokens.json',
    ' * Régénère avec `pnpm tokens:build` (depuis la racine).',
    ' */',
    ':root {',
  ];
  for (const [name, hex] of Object.entries(tokens.colors)) {
    lines.push(`  --piloo-color-${kebab(name)}: ${hex};`);
  }
  for (const [name, value] of Object.entries(tokens.radius)) {
    const unit = name === 'full' ? '9999px' : `${value}px`;
    lines.push(`  --piloo-radius-${kebab(name)}: ${unit};`);
  }
  for (const [name, value] of Object.entries(tokens.spacing)) {
    lines.push(`  --piloo-spacing-${kebab(name)}: ${value}px;`);
  }
  lines.push('}', '');
  return lines.join('\n');
}

const outputs = [
  {
    path: join(repoRoot, 'apps/mobile/lib/core/theme/colors.dart'),
    content: generateColorsDart(),
  },
  {
    path: join(repoRoot, 'apps/mobile/lib/core/theme/radius.dart'),
    content: generateRadiusDart(),
  },
  {
    path: join(repoRoot, 'apps/mobile/lib/core/theme/spacing.dart'),
    content: generateSpacingDart(),
  },
  {
    path: join(repoRoot, 'apps/web/styles/tokens.gen.css'),
    content: generateCss(),
  },
];

for (const { path, content } of outputs) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content);
  console.log(`✓ ${path.replace(`${repoRoot}/`, '')}`);
}
