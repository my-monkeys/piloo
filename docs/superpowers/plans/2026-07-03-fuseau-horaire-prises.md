# Support fuseau horaire réel pour les prises — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Les prises planifiées sont stockées comme de vrais instants UTC, convertis depuis/vers l'heure murale du fuseau de chaque officine, pour que les créneaux (matin/midi/soir/coucher) s'affichent correctement quel que soit le fuseau.

**Architecture:** `officines.timezone` (IANA, défaut `Europe/Paris`) est la source de vérité. Le serveur convertit heure murale officine → instant UTC à la génération (helper `Intl`). Le mobile convertit instant UTC → heure murale officine à l'affichage (lib `timezone` déjà présente). Un backfill régénère les prises futures existantes.

**Tech Stack:** Next.js 15 / TypeScript / Drizzle / Zod (serveur + contrat) ; Flutter / Dart / Riverpod / package `timezone` + `flutter_timezone` (mobile) ; Vitest (tests serveur) ; flutter_test (tests mobile).

## Global Constraints

- Fuseau stocké comme **nom IANA** (ex. `Europe/Paris`), jamais un offset fixe (DST).
- `datetime_prevue` (`timestamptz`) = **vrai instant UTC** — ne jamais y écrire une heure murale « telle quelle ».
- Bucketing des créneaux (matin/midi/soir/coucher) sur l'**heure locale officine**, jamais UTC ni device.
- Pas de nouvelle dépendance serveur (utiliser `Intl`). Mobile : réutiliser `timezone` (^0.10.1) + `flutter_timezone` (^4.1.1) déjà dans `pubspec.yaml`.
- Casing snake_case dans les schémas Zod du contrat.
- Soft delete partout (jamais de DELETE réel sur tables métier).
- Conventional Commits. Lancer lint + type-check avant chaque commit du côté concerné (`pnpm --filter <pkg> test` / `flutter analyze`).

---

### Task 1: Helper de conversion fuseau (serveur, pur)

**Files:**

- Create: `apps/web/lib/prises/timezone.ts`
- Test: `apps/web/test/timezone.spec.ts`

**Interfaces:**

- Produces:
  - `zonedWallClockToUtc(year: number, month: number, day: number, hours: number, minutes: number, timeZone: string): Date` — `month` est 1-based. Retourne l'instant UTC de l'heure murale donnée dans `timeZone`.
  - `utcToZonedParts(instant: Date, timeZone: string): { year: number; month: number; day: number; hour: number; minute: number }` — décompose un instant UTC en champs muraux dans `timeZone`.

- [ ] **Step 1: Write the failing tests**

```ts
// apps/web/test/timezone.spec.ts
import { describe, it, expect } from 'vitest';
import { zonedWallClockToUtc, utcToZonedParts } from '@/lib/prises/timezone';

describe('zonedWallClockToUtc', () => {
  it('Europe/Paris en été (DST +2) : 22:00 mural → 20:00Z', () => {
    const utc = zonedWallClockToUtc(2026, 7, 3, 22, 0, 'Europe/Paris');
    expect(utc.toISOString()).toBe('2026-07-03T20:00:00.000Z');
  });

  it('Europe/Paris en hiver (+1) : 22:00 mural → 21:00Z', () => {
    const utc = zonedWallClockToUtc(2026, 1, 15, 22, 0, 'Europe/Paris');
    expect(utc.toISOString()).toBe('2026-01-15T21:00:00.000Z');
  });

  it('America/New_York en été (-4) : 08:00 mural → 12:00Z', () => {
    const utc = zonedWallClockToUtc(2026, 7, 3, 8, 0, 'America/New_York');
    expect(utc.toISOString()).toBe('2026-07-03T12:00:00.000Z');
  });

  it('UTC : identité', () => {
    const utc = zonedWallClockToUtc(2026, 7, 3, 22, 0, 'UTC');
    expect(utc.toISOString()).toBe('2026-07-03T22:00:00.000Z');
  });
});

describe('utcToZonedParts', () => {
  it('20:00Z en Europe/Paris été → 22:00 mural', () => {
    const parts = utcToZonedParts(new Date('2026-07-03T20:00:00.000Z'), 'Europe/Paris');
    expect(parts).toMatchObject({ year: 2026, month: 7, day: 3, hour: 22, minute: 0 });
  });

  it('23:30Z en Europe/Paris été → 01:30 le lendemain', () => {
    const parts = utcToZonedParts(new Date('2026-07-03T23:30:00.000Z'), 'Europe/Paris');
    expect(parts).toMatchObject({ year: 2026, month: 7, day: 4, hour: 1, minute: 30 });
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pnpm --filter web test -- timezone`
Expected: FAIL (module `@/lib/prises/timezone` introuvable).

- [ ] **Step 3: Implement the helper**

```ts
// apps/web/lib/prises/timezone.ts
// Conversions heure murale ⇄ instant UTC pour un fuseau IANA, via Intl
// (DST-aware, sans dépendance). Utilisé pour planifier les prises dans le
// fuseau de l'officine (#363).

/** Décompose un instant en champs muraux (1-based month) dans `timeZone`. */
export function utcToZonedParts(
  instant: Date,
  timeZone: string,
): { year: number; month: number; day: number; hour: number; minute: number } {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  const parts = Object.fromEntries(fmt.formatToParts(instant).map((p) => [p.type, p.value]));
  let hour = Number(parts.hour);
  // Intl peut rendre "24" à minuit selon la locale/env — normaliser.
  if (hour === 24) hour = 0;
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour,
    minute: Number(parts.minute),
  };
}

/** Offset (ms) de `timeZone` à l'instant `date` : local - UTC. */
function tzOffsetMs(date: Date, timeZone: string): number {
  const p = utcToZonedParts(date, timeZone);
  // Instant qui, lu en UTC, a les mêmes champs que l'heure murale locale.
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, 0, 0);
  // Tronquer les secondes/ms de `date` pour comparer au même grain.
  const truncated = Math.floor(date.getTime() / 60_000) * 60_000;
  return asUtc - truncated;
}

/**
 * Instant UTC d'une heure murale (`month` 1-based) dans `timeZone`.
 * Deux passes pour converger sur l'offset correct autour des transitions DST.
 * Cas limites : gap de printemps → l'instant retombe après la transition ;
 * overlap d'automne → première occurrence. Déterministe.
 */
export function zonedWallClockToUtc(
  year: number,
  month: number,
  day: number,
  hours: number,
  minutes: number,
  timeZone: string,
): Date {
  const naiveUtc = Date.UTC(year, month - 1, day, hours, minutes, 0, 0);
  let guess = new Date(naiveUtc - tzOffsetMs(new Date(naiveUtc), timeZone));
  // 2e passe : re-mesure l'offset à l'instant estimé (corrige les bords DST).
  const offset2 = tzOffsetMs(guess, timeZone);
  guess = new Date(naiveUtc - offset2);
  return guess;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pnpm --filter web test -- timezone`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/web/lib/prises/timezone.ts apps/web/test/timezone.spec.ts
git commit -m "feat(prises): helper conversion heure murale ⇄ UTC par fuseau (#363)"
```

---

### Task 2: Colonne `officines.timezone` + migration

**Files:**

- Modify: `packages/db-schema/src/schema/officines.ts`
- Create (généré): `packages/db-schema/drizzle/*_officine_timezone.sql`

**Interfaces:**

- Produces: `officines.timezone` (type `string`, non-null, défaut `'Europe/Paris'`) sur le type Drizzle `Officine` / `NewOfficine`.

- [ ] **Step 1: Add the column**

Dans `packages/db-schema/src/schema/officines.ts`, après `notes: text(),` (ligne ~25) ajouter :

```ts
    // Fuseau IANA du carnet (source de vérité pour planifier/afficher les
    // prises). Défaut Europe/Paris pour les officines existantes (#363).
    timezone: text().notNull().default('Europe/Paris'),
```

- [ ] **Step 2: Generate the migration**

Run: `pnpm --filter @piloo/db-schema db:generate`
Expected: nouveau fichier SQL dans `packages/db-schema/drizzle/` ajoutant `timezone text NOT NULL DEFAULT 'Europe/Paris'`.

- [ ] **Step 3: Verify the migration SQL**

Ouvrir le `.sql` généré et confirmer :

```sql
ALTER TABLE "officines" ADD COLUMN "timezone" text DEFAULT 'Europe/Paris' NOT NULL;
```

- [ ] **Step 4: Commit**

```bash
git add packages/db-schema/src/schema/officines.ts packages/db-schema/drizzle/
git commit -m "feat(db): colonne officines.timezone (défaut Europe/Paris) (#363)"
```

---

### Task 3: Génération des prises en fuseau officine

**Files:**

- Modify: `apps/web/lib/prises/generate.ts`
- Test: `apps/web/test/prises-generate.spec.ts` (existant)

**Interfaces:**

- Consumes: `zonedWallClockToUtc` (Task 1).
- Produces: `GenerateOptions`, `WindowGenerateOptions`, `RappelGenerateOptions` gagnent `timeZone: string`. `composeDatetime(dateDebut, dayOffset, horaire, timeZone)`.

- [ ] **Step 1: Write the failing test**

Ajouter à `apps/web/test/prises-generate.spec.ts` :

```ts
import { zonedWallClockToUtc } from '@/lib/prises/timezone';

it('rappel coucher en Europe/Paris (été) → instant 20:00Z', () => {
  const prises = generatePrisesForRappel(
    { id: 'r1', quantiteMatin: null, quantiteMidi: null, quantiteSoir: null, quantiteCoucher: 1 },
    {
      officineId: 'o1',
      windowStart: new Date('2026-07-03T00:00:00.000Z'),
      windowDays: 1,
      timeZone: 'Europe/Paris',
    },
  );
  expect(prises).toHaveLength(1);
  expect(prises[0].datetimePrevue.toISOString()).toBe('2026-07-03T20:00:00.000Z');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter web test -- prises-generate`
Expected: FAIL (le champ `timeZone` n'existe pas ; l'instant est `22:00Z`).

- [ ] **Step 3: Thread `timeZone` and convert**

Dans `apps/web/lib/prises/generate.ts` :

1. Importer le helper en tête :

```ts
import { zonedWallClockToUtc } from './timezone';
```

2. Remplacer `composeDatetime` (actuellement `setUTCHours`) par :

```ts
/**
 * Compose l'instant UTC d'une heure murale `HH:MM` dans `timeZone`, pour le
 * jour `dateDebut + dayOffset` (jour lu en UTC — `dateDebut` = minuit de la
 * fenêtre). Le mural est interprété dans le fuseau de l'officine (#363).
 */
function composeDatetime(
  dateDebut: Date,
  dayOffset: number,
  horaire: string,
  timeZone: string,
): Date {
  const day = new Date(dateDebut);
  day.setUTCDate(day.getUTCDate() + dayOffset);
  const { hours, minutes } = parseHoraire(horaire);
  return zonedWallClockToUtc(
    day.getUTCFullYear(),
    day.getUTCMonth() + 1,
    day.getUTCDate(),
    hours,
    minutes,
    timeZone,
  );
}
```

3. Ajouter `timeZone: string;` à `GenerateOptions`, `WindowGenerateOptions`, `RappelGenerateOptions`.

4. Dans les 3 générateurs, passer le fuseau à chaque appel :

```ts
datetimePrevue: composeDatetime(options.dateDebut, offset, horaire, options.timeZone),
// resp. options.windowStart pour les variantes fenêtre
```

- [ ] **Step 4: Update existing tests that construct options**

Chaque appel de test à `generatePrisesFor*` doit ajouter `timeZone: 'Europe/Paris'` (ou `'UTC'` selon l'attendu). Pour les tests qui vérifiaient l'ancien comportement `setUTCHours`, passer `timeZone: 'UTC'` pour préserver l'attendu `22:00Z`, OU mettre à jour l'attendu.

- [ ] **Step 5: Run tests**

Run: `pnpm --filter web test -- prises-generate`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/web/lib/prises/generate.ts apps/web/test/prises-generate.spec.ts
git commit -m "feat(prises): génère les instants dans le fuseau de l'officine (#363)"
```

---

### Task 4: Threader `officine.timezone` dans les callers (reconcile, cron, routes)

**Files:**

- Modify: `apps/web/lib/rappels/reconcile.ts`
- Modify: `apps/web/lib/prises/cron-glissant.ts:70`
- Modify: `apps/web/app/api/v1/officines/[officineId]/rappels/route.ts`
- Modify (si présent) : les appels `generatePrisesForPrescription` (ordonnances)
- Test: `apps/web/test/rappels-reconcile.spec.ts` (existant)

**Interfaces:**

- Consumes: `generatePrisesForRappel/Window/Prescription` avec `timeZone` (Task 3), `officines.timezone` (Task 2).
- Produces: `buildInitialRappelPrises(rappel, timeZone, now?)` et `regenerateRappelPrises(db, rappelId, now?)` (qui fetch le fuseau via l'officine).

- [ ] **Step 1: Update `reconcile.ts` to fetch and pass the officine timezone**

Dans `apps/web/lib/rappels/reconcile.ts` :

1. Importer `officines` :

```ts
import {
  officines,
  prisesPlanifiees,
  rappels,
  type Db,
  type NewPrisePlanifiee,
  type Rappel,
} from '@piloo/db-schema';
```

2. `buildInitialRappelPrises` reçoit le fuseau :

```ts
export function buildInitialRappelPrises(
  rappel: Rappel,
  timeZone: string,
  now: Date = new Date(),
): NewPrisePlanifiee[] {
  // ... inchangé jusqu'au return ...
  return generatePrisesForRappel(rappel, {
    officineId: rappel.officineId,
    windowStart,
    windowDays,
    timeZone,
  });
}
```

3. `regenerateRappelPrises` fetch l'officine pour le fuseau :

```ts
export async function regenerateRappelPrises(
  db: Db,
  rappelId: string,
  now: Date = new Date(),
): Promise<number> {
  const [rappel] = await db.select().from(rappels).where(eq(rappels.id, rappelId)).limit(1);
  if (!rappel || rappel.deletedAt || !rappel.actif) return 0;
  const [officine] = await db
    .select({ timezone: officines.timezone })
    .from(officines)
    .where(eq(officines.id, rappel.officineId))
    .limit(1);
  const timeZone = officine?.timezone ?? 'Europe/Paris';
  const prises = buildInitialRappelPrises(rappel, timeZone, now);
  if (prises.length === 0) return 0;
  await db.insert(prisesPlanifiees).values(prises);
  return prises.length;
}
```

- [ ] **Step 2: Update the POST rappels route**

Dans `apps/web/app/api/v1/officines/[officineId]/rappels/route.ts`, là où `buildInitialRappelPrises` est appelé après création du rappel : récupérer `officine.timezone` (l'officine est déjà chargée pour le contrôle de rôle — sinon un `select({ timezone })`) et le passer en 2e argument.

- [ ] **Step 3: Update the cron**

Dans `apps/web/lib/prises/cron-glissant.ts` (~ligne 70), l'appel `generatePrisesForWindow(...)` : la boucle itère sur des prescriptions/officines — récupérer le `timezone` de l'officine concernée (ajouter au select de la requête qui charge les prescriptions/officines) et le passer dans les options.

- [ ] **Step 4: Update prescription generation callers (ordonnances)**

Rechercher les appels `generatePrisesForPrescription` (routes ordonnances) et passer `timeZone: officine.timezone` de la même façon.

- [ ] **Step 5: Update tests**

`apps/web/test/rappels-reconcile.spec.ts` : les appels à `buildInitialRappelPrises` prennent maintenant `timeZone` en 2e argument (`'Europe/Paris'`). Ajouter un cas vérifiant qu'un rappel coucher donne un instant `…T20:00:00Z` en été.

- [ ] **Step 6: Run tests**

Run: `pnpm --filter web test -- rappels`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/web/lib/rappels/reconcile.ts apps/web/lib/prises/cron-glissant.ts apps/web/app/api/v1/officines apps/web/test/rappels-reconcile.spec.ts
git commit -m "feat(prises): passe le fuseau officine aux générateurs (rappels/cron/ordo) (#363)"
```

---

### Task 5: Mapping quantité (serialize) en fuseau officine

**Files:**

- Modify: `apps/web/lib/prises/serialize.ts`
- Modify: le caller GET `/v1/prises` (route qui appelle `serializePriseTimelineItem`)
- Test: `apps/web/test/prises.spec.ts` (existant)

**Interfaces:**

- Consumes: `utcToZonedParts` (Task 1), `officines.timezone`.
- Produces: `serializePriseTimelineItem(prise, prescription, rappel, timeZone)`.

- [ ] **Step 1: Write the failing test**

Dans `apps/web/test/prises.spec.ts`, ajouter :

```ts
it('rappel coucher stocké 20:00Z (Europe/Paris) → quantité coucher', () => {
  const prise = { datetimePrevue: new Date('2026-07-03T20:00:00.000Z') } as any;
  const rappel = {
    quantiteMatin: null,
    quantiteMidi: null,
    quantiteSoir: null,
    quantiteCoucher: 2,
  } as any;
  const item = serializePriseTimelineItem(prise, null, rappel, 'Europe/Paris');
  expect((item.prescription.posologie as any).unitesParPrise).toBe(2);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter web test -- prises.spec`
Expected: FAIL (signature sans `timeZone` ; bucketing UTC donnerait 20h → soir, quantité null).

- [ ] **Step 3: Implement**

Dans `apps/web/lib/prises/serialize.ts` :

1. Importer :

```ts
import { utcToZonedParts } from './timezone';
```

2. `rappelQuantityForDatetime` prend le fuseau :

```ts
function rappelQuantityForDatetime(
  prise: PrisePlanifiee,
  rappel: Rappel,
  timeZone: string,
): number | null {
  const { hour } = utcToZonedParts(prise.datetimePrevue, timeZone);
  if (hour < 10) return rappel.quantiteMatin;
  if (hour < 16) return rappel.quantiteMidi;
  if (hour < 21) return rappel.quantiteSoir;
  return rappel.quantiteCoucher;
}
```

3. `serializePriseTimelineItem` prend `timeZone: string` (nouveau param) et le passe à `buildSyntheticPrescriptionFromRappel` → `rappelQuantityForDatetime`.

- [ ] **Step 4: Update the GET /v1/prises caller**

Dans la route GET `/v1/prises`, charger `officine.timezone` (l'officine est identifiée par `officine_id` de la query) et le passer à chaque `serializePriseTimelineItem(...)`.

- [ ] **Step 5: Run tests**

Run: `pnpm --filter web test -- prises.spec`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/web/lib/prises/serialize.ts apps/web/app/api/v1/prises apps/web/test/prises.spec.ts
git commit -m "feat(prises): bucketing quantité rappel en fuseau officine (#363)"
```

---

### Task 6: Contrat API — `timezone` sur Officine

**Files:**

- Modify: `packages/api-contract/src/schemas/officines.ts`
- Regenerate: `packages/api-contract/openapi.yaml` + client Dart `apps/mobile/lib/gen/openapi`

**Interfaces:**

- Produces: champ `timezone: string` sur `OfficineSchema`, `CreateOfficineInputSchema` (optionnel), `UpdateOfficineInputSchema` (optionnel). Côté Dart généré : `Officine.timezone`.

- [ ] **Step 1: Add `timezone` to the schemas**

Dans `packages/api-contract/src/schemas/officines.ts` :

`OfficineSchema` (après `notes`) :

```ts
    timezone: z.string().min(1).max(64),
```

`CreateOfficineInputSchema` (le mobile envoie le fuseau device à la création) :

```ts
    timezone: z.string().min(1).max(64).optional(),
```

`UpdateOfficineInputSchema` (picker) :

```ts
    timezone: z.string().min(1).max(64).optional(),
```

- [ ] **Step 2: Regenerate OpenAPI + Dart client**

Run: `pnpm --filter @piloo/api-contract generate` (ou `pnpm openapi:generate` selon le script racine)
Expected: `openapi.yaml` mis à jour avec `timezone` ; `apps/mobile/lib/gen/openapi` régénéré (le modèle `Officine` a `timezone`).

- [ ] **Step 3: Verify the Dart model**

Confirmer que `apps/mobile/lib/gen/openapi/.../model/officine.dart` expose `String get timezone;`.

- [ ] **Step 4: Commit**

```bash
git add packages/api-contract apps/mobile/lib/gen
git commit -m "feat(contract): timezone sur Officine + inputs create/update (#363)"
```

---

### Task 7: Routes officine serveur — accepter/retourner `timezone`

**Files:**

- Modify: `apps/web/app/api/v1/officines/route.ts` (POST)
- Modify: `apps/web/app/api/v1/officines/[officineId]/route.ts` (PATCH, GET)

**Interfaces:**

- Consumes: `CreateOfficineInput.timezone?`, `UpdateOfficineInput.timezone?`, `officines.timezone`.

- [ ] **Step 1: POST — persist provided timezone (default Europe/Paris)**

Dans le POST : à l'insert de l'officine, ajouter `timezone: input.timezone ?? 'Europe/Paris'`. S'assurer que le mapping DB→réponse inclut `timezone`.

- [ ] **Step 2: PATCH — allow updating timezone**

Dans le PATCH : si `input.timezone` présent, l'inclure dans le `set({...})`. Valider (déjà fait par Zod). Le mapping réponse inclut `timezone`.

- [ ] **Step 3: GET/serialisation — expose timezone**

Vérifier que le sérialiseur officine (fonction qui construit l'objet réponse depuis la row DB) copie `timezone`. L'ajouter s'il fait un mapping explicite champ par champ.

- [ ] **Step 4: Test the round-trip**

Ajouter/mettre à jour un test de route (`apps/web/test/officines-route.spec.ts` s'il existe, sinon vérifier via un test existant) : POST avec `timezone: 'America/New_York'` → GET renvoie `timezone: 'America/New_York'` ; POST sans `timezone` → `Europe/Paris`.

- [ ] **Step 5: Run tests + commit**

Run: `pnpm --filter web test -- officines`
Expected: PASS.

```bash
git add apps/web/app/api/v1/officines apps/web/test
git commit -m "feat(officines): create/patch/get gèrent timezone (#363)"
```

---

### Task 8: Mobile — affichage des prises en fuseau officine

**Files:**

- Modify: `apps/mobile/lib/features/today/presentation/today_screen.dart`
- Modify: `apps/mobile/lib/main.dart` (init base tz si pas déjà fait globalement)
- Test: `apps/mobile/test/features/today/today_moment_bucketing_test.dart` (créer)

**Interfaces:**

- Consumes: `Officine.timezone` (Task 6), `activeOfficineProvider`, package `timezone`.
- Produces: fonction pure testable `momentBucketFor(DateTime instantUtc, String timeZone) → Moment` + `wallClockLabel(DateTime instantUtc, String timeZone) → String`.

- [ ] **Step 1: Extract pure bucketing/label helpers with a failing test**

Créer `apps/mobile/lib/features/today/data/moment_bucket.dart` :

```dart
// Créneau + libellé d'heure d'une prise dans le fuseau de l'officine (#363).
import 'package:timezone/timezone.dart' as tz;

enum Moment { matin, midi, soir, coucher }

Moment momentBucketFor(DateTime instantUtc, String timeZone) {
  final local = tz.TZDateTime.from(instantUtc, tz.getLocation(timeZone));
  return switch (local.hour) {
    < 12 => Moment.matin,
    < 16 => Moment.midi,
    < 21 => Moment.soir,
    _ => Moment.coucher,
  };
}

String wallClockLabel(DateTime instantUtc, String timeZone) {
  final local = tz.TZDateTime.from(instantUtc, tz.getLocation(timeZone));
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
```

Test `apps/mobile/test/features/today/moment_bucket_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:piloo/features/today/data/moment_bucket.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('coucher 20:00Z en Europe/Paris (été) → Coucher, 22:00', () {
    final instant = DateTime.parse('2026-07-03T20:00:00.000Z');
    expect(momentBucketFor(instant, 'Europe/Paris'), Moment.coucher);
    expect(wallClockLabel(instant, 'Europe/Paris'), '22:00');
  });

  test('soir 17:00Z en Europe/Paris (été) → Soir, 19:00', () {
    final instant = DateTime.parse('2026-07-03T17:00:00.000Z');
    expect(momentBucketFor(instant, 'Europe/Paris'), Moment.soir);
    expect(wallClockLabel(instant, 'Europe/Paris'), '19:00');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/features/today/moment_bucket_test.dart`
Expected: FAIL (fichier `moment_bucket.dart` absent).

- [ ] **Step 3: Create the helper file (code from Step 1) and re-run**

Run: `cd apps/mobile && flutter test test/features/today/moment_bucket_test.dart`
Expected: PASS.

- [ ] **Step 4: Wire the helpers into `today_screen.dart`**

- Résoudre le fuseau de l'officine active : lire `activeOfficineProvider` dans le `build` et récupérer `officine.timezone` (fallback `'Europe/Paris'` si loading).
- `_groupByMoment` : remplacer `final local = p.datetimePrevue.toLocal();` + le `switch` par `momentBucketFor(p.datetimePrevue, timeZone)`.
- `_mapApiPrise` : le libellé d'heure via `wallClockLabel(p.datetimePrevue, timeZone)`.
- `_onPriseTap` : idem pour `scheduledLabel`.
- S'assurer que la base tz est initialisée au boot (`main.dart` : `tz.initializeTimeZones()` — le service notifs le fait peut-être déjà ; sinon l'ajouter tôt dans `main`).

- [ ] **Step 5: Fix the edit picker (`_onPriseLongPress`)**

Le picker doit présenter et interpréter l'heure en fuseau officine :

```dart
final loc = tz.getLocation(timeZone);
final initial = tz.TZDateTime.from(apiPrise.datetimePrevue, loc);
// ... showDatePicker/showTimePicker avec `initial` ...
final nextUtc = tz.TZDateTime(
  loc, pickedDate.year, pickedDate.month, pickedDate.day,
  pickedTime.hour, pickedTime.minute,
).toUtc();
await updatePriseDatetime(ref, priseId: apiPrise.id, officineId: apiPrise.officineId, date: isoDate(_date), datetimePrevue: nextUtc);
```

(`updatePriseDatetime` fait déjà `.toUtc()` — passer un `DateTime` déjà UTC est idempotent.)

- [ ] **Step 6: Run analyze + the bucketing test**

Run: `cd apps/mobile && flutter analyze lib/features/today test/features/today && flutter test test/features/today/moment_bucket_test.dart`
Expected: analyze clean sur ces chemins ; test PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/lib/features/today apps/mobile/lib/main.dart apps/mobile/test/features/today
git commit -m "feat(mobile): affiche les prises dans le fuseau de l'officine (#363)"
```

---

### Task 9: Mobile — déduire le fuseau du device à la création d'officine

**Files:**

- Modify: `apps/mobile/lib/features/officines/data/active_officine_provider.dart`

**Interfaces:**

- Consumes: `flutter_timezone`, `CreateOfficineInput.timezone` (Task 6).

- [ ] **Step 1: Pass device timezone when auto-creating "Maison"**

Dans `_resolve()`, avant `api.v1OfficinesPost(...)` :

```dart
import 'package:flutter_timezone/flutter_timezone.dart';
// ...
final deviceTz = await FlutterTimezone.getLocalTimezone();
final builder = CreateOfficineInputBuilder()
  ..nom = 'Maison'
  ..type = CreateOfficineInputTypeEnum.perso
  ..timezone = deviceTz;
```

(`FlutterTimezone.getLocalTimezone()` retourne un nom IANA, ex. `Europe/Paris`.)

- [ ] **Step 2: Verify analyze**

Run: `cd apps/mobile && flutter analyze lib/features/officines`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/lib/features/officines/data/active_officine_provider.dart
git commit -m "feat(mobile): déduit le fuseau du device à la création d'officine (#363)"
```

---

### Task 10: Mobile — écran Réglages officine avec picker de fuseau

**Files:**

- Create: `apps/mobile/lib/features/officines/presentation/officine_settings_screen.dart`
- Modify: `apps/mobile/lib/core/router/router.dart` (remplacer le `PlaceholderScreen` de `officineSettings`)
- Modify: `apps/mobile/lib/features/officines/data/*` (ajouter `updateOfficineTimezone`)

**Interfaces:**

- Consumes: `Officine.timezone`, `UpdateOfficineInput.timezone`, package `timezone` (liste des locations).
- Produces: écran `OfficineSettingsScreen(officineId)`.

- [ ] **Step 1: Add a data function to PATCH the timezone**

Dans le provider officines, ajouter :

```dart
Future<void> updateOfficineTimezone(WidgetRef ref, {required String officineId, required String timezone}) async {
  final apiOff = ref.read(pilooApiClientProvider).getOfficinesApi();
  final input = (UpdateOfficineInputBuilder()..timezone = timezone).build();
  final res = await apiOff.v1OfficinesIdPatch(id: officineId, updateOfficineInput: input);
  if (res.statusCode != 200) throw Exception('MAJ fuseau : statut ${res.statusCode}');
  ref.invalidate(activeOfficineProvider);
}
```

- [ ] **Step 2: Build the picker screen**

`officine_settings_screen.dart` : un écran avec un champ de recherche + liste filtrable de `tz.timeZoneDatabase.locations.keys` (noms IANA), sélection courante = `officine.timezone`. Au tap sur un fuseau → `updateOfficineTimezone` + toast + retour. Suivre le style des écrans settings existants (`horaires_screen.dart` pour l'ossature header + liste).

- [ ] **Step 3: Route it**

Dans `router.dart`, remplacer le `PlaceholderScreen` de la route `officineSettings` par `OfficineSettingsScreen(officineId: state.pathParameters['officineId'] ?? '')`.

- [ ] **Step 4: Verify in the running app**

Run l'app (simulateur), aller Réglages officine → changer le fuseau → vérifier que les prises se réaffichent aux bons créneaux. (Nécessite l'accord pour lancer l'app.)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/officines apps/mobile/lib/core/router/router.dart
git commit -m "feat(mobile): écran réglages officine + picker de fuseau (#363)"
```

---

### Task 11: Notifications — libellé d'heure en fuseau officine

**Files:**

- Modify: `apps/mobile/lib/shared/notifications/notifications_service.dart`

**Interfaces:**

- Consumes: `Officine.timezone`, `wallClockLabel` (Task 8).

- [ ] **Step 1: Use the officine timezone for the notification time label**

`scheduleForPrises` reçoit (ou lit) le fuseau de l'officine active. La planification (`tz.TZDateTime.from(scheduled, tz.local)`) reste correcte à l'instant absolu (l'instant stocké est désormais vrai), mais le **texte** `hh:mm` de la notif doit utiliser `wallClockLabel(p.datetimePrevue, timeZone)` au lieu de `scheduled.hour/minute`. Passer le `timeZone` en paramètre de `scheduleForPrises` depuis l'appelant (`prises_provider._fetchFromApi`, qui a l'officine).

- [ ] **Step 2: Verify analyze**

Run: `cd apps/mobile && flutter analyze lib/shared/notifications lib/features/today/data/prises_provider.dart`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/lib/shared/notifications apps/mobile/lib/features/today/data/prises_provider.dart
git commit -m "feat(mobile): libellé d'heure des notifs en fuseau officine (#363)"
```

---

### Task 12: Backfill des prises futures existantes

**Files:**

- Create: `apps/web/scripts/backfill-prises-timezone.ts`

**Interfaces:**

- Consumes: `cancelFutureRappelPrises` + `regenerateRappelPrises` (Task 4), l'équivalent prescriptions.

- [ ] **Step 1: Write the backfill script**

`apps/web/scripts/backfill-prises-timezone.ts` : pour chaque rappel actif (non soft-deleted, `actif`), exécuter le pattern cancel-then-regenerate déjà existant (`cancelFutureRappelPrises` puis `regenerateRappelPrises`), qui régénère avec le fuseau officine (Task 4). Idem pour les prescriptions à durée fixe / à vie avec futures `prevue`. Logguer le nombre de prises régénérées par entité (sans données sensibles : IDs seulement).

```ts
// apps/web/scripts/backfill-prises-timezone.ts
// One-shot post-deploy (#363) : régénère les prises futures `prevue` avec le
// fuseau de l'officine. Idempotent. Ne touche pas l'historique.
import { db } from '@/lib/db';
import { rappels } from '@piloo/db-schema';
import { and, eq, isNull } from 'drizzle-orm';
import { cancelFutureRappelPrises, regenerateRappelPrises } from '@/lib/rappels/reconcile';

async function main() {
  const actifs = await db
    .select({ id: rappels.id })
    .from(rappels)
    .where(and(eq(rappels.actif, true), isNull(rappels.deletedAt)));
  let total = 0;
  for (const { id } of actifs) {
    await cancelFutureRappelPrises(db, id);
    const n = await regenerateRappelPrises(db, id);
    total += n;
    console.log(`rappel ${id}: ${n} prises régénérées`);
  }
  console.log(`Terminé : ${total} prises régénérées sur ${actifs.length} rappels.`);
}
main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
```

(Étendre pour les prescriptions si des prises `prevue` futures issues d'ordonnances existent.)

- [ ] **Step 2: Dry-run mental / count check**

Documenter dans le PR comment lancer le script post-deploy (`pnpm --filter web tsx scripts/backfill-prises-timezone.ts` sur le serveur, ou via une route admin protégée). Ne pas l'exécuter automatiquement au build.

- [ ] **Step 3: Commit**

```bash
git add apps/web/scripts/backfill-prises-timezone.ts
git commit -m "chore(prises): script backfill des prises futures en fuseau officine (#363)"
```

---

## Ordre & dépendances

1 (helper) → 2 (schéma) → 3 (generate) → 4 (callers) → 5 (serialize) → 6 (contrat) → 7 (routes officine) → 8 (mobile affichage) → 9 (création) → 10 (picker) → 11 (notifs) → 12 (backfill).

Tasks 1–5 et 7 = serveur (testables via Vitest). 6 = contrat (régénération). 8–11 = mobile. 12 = migration one-shot. Le mobile (8+) dépend de la régénération du client Dart (Task 6).

## Vérification finale

- Serveur : `pnpm --filter web test` vert.
- Mobile : `flutter analyze` (avec `build/**` exclu — réappliquer l'exclusion `analysis_options.yaml` si #362 pas encore mergé) + `flutter test test/features/today/moment_bucket_test.dart`.
- Bout-en-bout (avec accord pour lancer l'app) : créer un rappel « coucher », vérifier qu'il apparaît dans le créneau **Coucher** à **22:00** sur un device en Europe/Paris **et** sur un device réglé sur un autre fuseau.
- Backfill lancé post-deploy ; vérifier qu'un rappel coucher existant repasse de Matin à Coucher.
