#!/usr/bin/env node
/**
 * Met à jour le champ `version:` de `apps/mobile/pubspec.yaml` à partir d'un
 * tag git du monorepo (format `v1.2.3`).
 *
 * Le format Flutter est `MAJEUR.MINEUR.PATCH+BUILD` où `BUILD` est un entier
 * monotone croissant (CFBundleVersion iOS / versionCode Android). On le dérive
 * du nombre total de commits sur HEAD pour rester monotone sans état externe.
 *
 * Usage :
 *   node scripts/set-mobile-version.mjs                       # tag = git describe
 *   node scripts/set-mobile-version.mjs --tag v1.2.3
 *   node scripts/set-mobile-version.mjs --tag v1.2.3 --build-number 42
 *   node scripts/set-mobile-version.mjs --pubspec path/pubspec.yaml --dry-run
 *
 * Sources de tag (par ordre de priorité) :
 *   1. --tag <vX.Y.Z>
 *   2. GITHUB_REF (`refs/tags/vX.Y.Z`)
 *   3. `git describe --tags --match 'v*' --abbrev=0`
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';

const SEMVER_TAG_RE = /^v(\d+)\.(\d+)\.(\d+)$/;
const PUBSPEC_VERSION_LINE_RE = /^version:\s*.*$/m;

export function parseTagToSemver(tag) {
  if (typeof tag !== 'string') {
    throw new TypeError(`tag must be a string, got ${typeof tag}`);
  }
  const trimmed = tag.trim();
  const match = SEMVER_TAG_RE.exec(trimmed);
  if (!match) {
    throw new Error(
      `tag invalide : "${tag}". Attendu format vMAJEUR.MINEUR.PATCH (ex: v1.2.3).`,
    );
  }
  const [, major, minor, patch] = match;
  return `${Number(major)}.${Number(minor)}.${Number(patch)}`;
}

export function formatPubspecVersion(semver, buildNumber) {
  if (!/^\d+\.\d+\.\d+$/.test(semver)) {
    throw new Error(`semver invalide : "${semver}"`);
  }
  if (!Number.isInteger(buildNumber) || buildNumber <= 0) {
    throw new Error(
      `buildNumber doit être un entier > 0, reçu : ${buildNumber}`,
    );
  }
  return `${semver}+${buildNumber}`;
}

export function updatePubspecContent(content, newVersion) {
  if (typeof content !== 'string') {
    throw new TypeError('content must be a string');
  }
  if (!PUBSPEC_VERSION_LINE_RE.test(content)) {
    throw new Error(
      "pubspec.yaml ne contient pas de ligne `version:`. Ajoute-la avant d'utiliser ce script.",
    );
  }
  return content.replace(PUBSPEC_VERSION_LINE_RE, `version: ${newVersion}`);
}

export function tagFromGithubRef(ref) {
  if (typeof ref !== 'string' || ref.length === 0) return null;
  const prefix = 'refs/tags/';
  if (ref.startsWith(prefix)) return ref.slice(prefix.length);
  return null;
}

function parseArgs(argv) {
  const out = { tag: null, buildNumber: null, pubspec: null, dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case '--tag':
        out.tag = argv[++i];
        break;
      case '--build-number':
        out.buildNumber = Number(argv[++i]);
        break;
      case '--pubspec':
        out.pubspec = argv[++i];
        break;
      case '--dry-run':
        out.dryRun = true;
        break;
      case '-h':
      case '--help':
        out.help = true;
        break;
      default:
        throw new Error(`argument inconnu : ${a}`);
    }
  }
  return out;
}

function detectTag(explicitTag) {
  if (explicitTag) return explicitTag;
  const fromEnv = tagFromGithubRef(process.env.GITHUB_REF ?? '');
  if (fromEnv) return fromEnv;
  return execFileSync(
    'git',
    ['describe', '--tags', '--match', 'v*', '--abbrev=0'],
    { encoding: 'utf8' },
  ).trim();
}

function detectBuildNumber(explicit) {
  if (Number.isInteger(explicit) && explicit > 0) return explicit;
  const out = execFileSync('git', ['rev-list', '--count', 'HEAD'], {
    encoding: 'utf8',
  }).trim();
  const n = Number(out);
  if (!Number.isInteger(n) || n <= 0) {
    throw new Error(`git rev-list a retourné un nombre invalide : "${out}"`);
  }
  return n;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    process.stdout.write(
      'Usage: set-mobile-version.mjs [--tag vX.Y.Z] [--build-number N] [--pubspec path] [--dry-run]\n',
    );
    return;
  }

  const tag = detectTag(args.tag);
  const semver = parseTagToSemver(tag);
  const buildNumber = detectBuildNumber(args.buildNumber);
  const version = formatPubspecVersion(semver, buildNumber);

  const pubspecPath = resolve(args.pubspec ?? 'apps/mobile/pubspec.yaml');
  if (!existsSync(pubspecPath)) {
    throw new Error(`pubspec.yaml introuvable : ${pubspecPath}`);
  }
  const before = readFileSync(pubspecPath, 'utf8');
  const after = updatePubspecContent(before, version);

  if (args.dryRun) {
    process.stdout.write(
      `[dry-run] tag=${tag} version=${version} pubspec=${pubspecPath}\n`,
    );
    return;
  }

  if (after !== before) writeFileSync(pubspecPath, after);
  process.stdout.write(`set version: ${version} in ${pubspecPath}\n`);
}

const isMain =
  import.meta.url === `file://${process.argv[1]}` ||
  import.meta.url.endsWith(process.argv[1]);
if (isMain) {
  try {
    main();
  } catch (err) {
    process.stderr.write(`error: ${err instanceof Error ? err.message : err}\n`);
    process.exit(1);
  }
}
