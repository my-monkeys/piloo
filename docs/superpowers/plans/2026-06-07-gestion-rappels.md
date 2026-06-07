# Gestion des rappels (« Mes rappels ») — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Donner aux utilisateurs un écran « Mes rappels » (mobile + web) pour lister, mettre en pause/réactiver, modifier et supprimer les rappels rapides déjà créés, en réconciliant les prises futures.

**Architecture:** L'API CRUD rappels existe déjà (`GET/PATCH/DELETE /v1/rappels/{id}`, `GET /v1/officines/{id}/rappels`). On ajoute (A) une réconciliation des `prises_planifiees` futures côté backend sur PATCH/DELETE, (B) un écran + mutations côté mobile Flutter, (C) une page + mutations côté web Next.js. La timeline (`listPrisesForDay`) masque déjà les prises d'un rappel soft-deleted ; il reste à gérer pause + édition d'horaires.

**Tech Stack:** Next.js 15 API routes + Drizzle + Vitest (testcontainers) ; Flutter + Riverpod + client OpenAPI généré ; openapi-react-query (`$api`) côté web.

**Spec de référence :** `docs/superpowers/specs/2026-06-07-gestion-rappels-design.md`

**Branche & ticket :** créer le ticket GitHub d'abord, brancher `feat/<num>-gestion-rappels` depuis `main` (cf. Task 0).

---

## Fichiers touchés

**Backend**

- Create: `apps/web/lib/rappels/reconcile.ts` — `cancelFutureRappelPrises`, `regenerateRappelPrises`.
- Create: `apps/web/test/rappels-reconcile.spec.ts` — tests d'intégration réconciliation.
- Modify: `apps/web/app/api/v1/rappels/[id]/route.ts` — PATCH/DELETE appellent la réconciliation.
- Modify: `apps/web/app/api/v1/officines/[officineId]/rappels/route.ts:91-118` — POST réutilise `regenerateRappelPrises` (DRY).

**Mobile**

- Modify: `apps/mobile/lib/features/rappels/data/rappels_provider.dart` — `updateRappel`, `deleteRappel`, `toggleRappelActif`.
- Modify: `apps/mobile/lib/core/router/routes.dart` — `RouteName.rappels`, `RoutePath.rappels`.
- Modify: `apps/mobile/lib/core/router/router.dart` — route go_router → `RappelsScreen`.
- Create: `apps/mobile/lib/features/rappels/presentation/rappels_screen.dart` — écran liste + actions.
- Modify: `apps/mobile/lib/features/more/presentation/more_screen.dart:65-82` — ligne « Mes rappels ».
- Modify: `apps/mobile/lib/features/rappels/presentation/rappel_quick_sheet.dart` — mode édition (pré-rempli + notes + dates).

**Web**

- Modify: `apps/web/components/app/sidebar.tsx:23-29` — item nav « Rappels ».
- Create: `apps/web/app/(app)/rappels/page.tsx` — page liste.
- Create: `apps/web/components/app/rappels/rappel-form-dialog.tsx` — dialog création/édition.

---

## Task 0 : Ticket + branche

- [ ] **Step 1 : Créer le ticket GitHub**

```bash
gh issue create --repo my-monkeys/piloo \
  --title "feat: écran de gestion des rappels (Mes rappels) — mobile + web" \
  --body "Écran pour lister / pause / modifier / supprimer les rappels créés, avec réconciliation des prises futures. Spec: docs/superpowers/specs/2026-06-07-gestion-rappels-design.md" \
  --assignee @me
```

- [ ] **Step 2 : Brancher depuis main** (remplacer `<num>` par le numéro retourné)

```bash
git checkout main
gh issue develop <num> --repo my-monkeys/piloo --name feat/<num>-gestion-rappels --base main --checkout
```

- [ ] **Step 3 : Récupérer spec + plan** (committés sur `feat/gestion-rappels`)

```bash
git cherry-pick main..feat/gestion-rappels
```

Expected: présence de `docs/superpowers/specs/2026-06-07-gestion-rappels-design.md` et `docs/superpowers/plans/2026-06-07-gestion-rappels.md` sur la branche.

---

## Phase A — Backend : réconciliation des prises

### Task A1 : `cancelFutureRappelPrises`

Mirror de `cancelFuturePrises` (`apps/web/lib/prises/cron-glissant.ts:116-134`) mais sur `rappelId`. Soft-delete les prises **futures non encore prises** d'un rappel.

**Files:**

- Create: `apps/web/lib/rappels/reconcile.ts`
- Test: `apps/web/test/rappels-reconcile.spec.ts`

- [ ] **Step 1 : Écrire le test d'échec** (créer le fichier de test avec le harnais standard)

```ts
// apps/web/test/rappels-reconcile.spec.ts
import { officines, partages, rappels, prisesPlanifiees, users } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { cancelFutureRappelPrises } from '@/lib/rappels/reconcile';

let env: TestDb;
beforeAll(async () => {
  env = await setupTestDb();
}, 90_000);
afterAll(async () => {
  await env.teardown();
});
beforeEach(async () => {
  await env.handle.client`
    TRUNCATE TABLE prises_planifiees, rappels, partages, officines, users
    RESTART IDENTITY CASCADE
  `;
});

/** Crée user + officine + rappel, renvoie leurs ids. */
async function seedRappel(): Promise<{ officineId: string; rappelId: string; userId: string }> {
  const db = env.handle.db;
  const [u] = await db
    .insert(users)
    .values({
      email: 'a@test.fr',
      name: 'A',
      nom: 'A',
      prenom: 'A',
      typeCompte: 'particulier',
    })
    .returning();
  const [o] = await db
    .insert(officines)
    .values({ nom: 'Maison', type: 'perso', proprietaireUserId: u!.id })
    .returning();
  const [r] = await db
    .insert(rappels)
    .values({
      officineId: o!.id,
      cip13: '3400930000000',
      nomTexte: 'Doliprane',
      quantiteMatin: 1,
      dateDebut: '2026-06-01',
      creeParUserId: u!.id,
    })
    .returning();
  return { officineId: o!.id, rappelId: r!.id, userId: u!.id };
}

describe('cancelFutureRappelPrises', () => {
  it('soft-delete les prises prevue futures, garde passées et déjà prises', async () => {
    const db = env.handle.db;
    const { officineId, rappelId } = await seedRappel();
    const now = new Date('2026-06-10T08:00:00.000Z');
    await db.insert(prisesPlanifiees).values([
      {
        rappelId,
        officineId,
        datetimePrevue: new Date('2026-06-09T08:00:00.000Z'),
        statut: 'prevue',
      }, // passée
      {
        rappelId,
        officineId,
        datetimePrevue: new Date('2026-06-11T08:00:00.000Z'),
        statut: 'prevue',
      }, // future
      {
        rappelId,
        officineId,
        datetimePrevue: new Date('2026-06-12T08:00:00.000Z'),
        statut: 'prise',
      }, // future mais prise
    ]);

    const cancelled = await cancelFutureRappelPrises(db, rappelId, now);

    expect(cancelled).toBe(1);
    const rows = await db.select().from(prisesPlanifiees);
    const future = rows.find(
      (p) => p.datetimePrevue.getTime() === new Date('2026-06-11T08:00:00.000Z').getTime(),
    );
    const past = rows.find(
      (p) => p.datetimePrevue.getTime() === new Date('2026-06-09T08:00:00.000Z').getTime(),
    );
    const taken = rows.find((p) => p.statut === 'prise');
    expect(future!.deletedAt).not.toBeNull();
    expect(past!.deletedAt).toBeNull();
    expect(taken!.deletedAt).toBeNull();
  });
});
```

- [ ] **Step 2 : Lancer le test, vérifier l'échec**

Run: `cd apps/web && pnpm vitest run test/rappels-reconcile.spec.ts`
Expected: FAIL — `Cannot find module '@/lib/rappels/reconcile'`.

- [ ] **Step 3 : Implémenter `cancelFutureRappelPrises`**

```ts
// apps/web/lib/rappels/reconcile.ts
// Réconciliation des prises_planifiees lors de la gestion d'un rappel
// (pause / édition / suppression). Mirror de cancelFuturePrises
// (prescriptions) côté rappels — cf. spec gestion-rappels §5.
import { prisesPlanifiees, type Db, type Rappel } from '@piloo/db-schema';
import { and, eq, gte, isNull } from 'drizzle-orm';

import { generatePrisesForRappel } from '@/lib/prises/generate';

/** Soft-delete les prises `prevue` futures (datetime >= now) d'un rappel.
 *  Les prises passées ou déjà `prise`/`sautee` sont préservées (historique). */
export async function cancelFutureRappelPrises(
  db: Db,
  rappelId: string,
  now: Date = new Date(),
): Promise<number> {
  const result = await db
    .update(prisesPlanifiees)
    .set({ deletedAt: now, updatedAt: now })
    .where(
      and(
        eq(prisesPlanifiees.rappelId, rappelId),
        eq(prisesPlanifiees.statut, 'prevue'),
        gte(prisesPlanifiees.datetimePrevue, now),
        isNull(prisesPlanifiees.deletedAt),
      ),
    )
    .returning({ id: prisesPlanifiees.id });
  return result.length;
}
```

- [ ] **Step 4 : Lancer le test, vérifier le succès**

Run: `cd apps/web && pnpm vitest run test/rappels-reconcile.spec.ts`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add apps/web/lib/rappels/reconcile.ts apps/web/test/rappels-reconcile.spec.ts
git commit -m "feat(rappels): cancelFutureRappelPrises — soft-delete prises futures (#<num>)"
```

### Task A2 : `regenerateRappelPrises` + DRY du POST

Factorise la génération de fenêtre initiale (actuellement inline dans `POST /officines/{id}/rappels`, lignes 91-118) dans `reconcile.ts`, réutilisée par le POST et la réactivation/édition.

**Files:**

- Modify: `apps/web/lib/rappels/reconcile.ts`
- Modify: `apps/web/app/api/v1/officines/[officineId]/rappels/route.ts`
- Test: `apps/web/test/rappels-reconcile.spec.ts`

- [ ] **Step 1 : Ajouter le test d'échec**

```ts
// Ajouter dans test/rappels-reconcile.spec.ts
import { regenerateRappelPrises } from '@/lib/rappels/reconcile';

describe('regenerateRappelPrises', () => {
  it('génère la fenêtre initiale (30j) à partir de max(today, dateDebut)', async () => {
    const db = env.handle.db;
    const { officineId, rappelId } = await seedRappel(); // quantiteMatin=1, dateDebut 2026-06-01
    const now = new Date('2026-06-10T09:00:00.000Z');

    const created = await regenerateRappelPrises(db, rappelId, now);

    expect(created).toBe(30); // 1 moment (matin) × 30 jours
    const rows = await db.select().from(prisesPlanifiees);
    expect(rows).toHaveLength(30);
    // démarre aujourd'hui (dateDebut passée), à 08:00 UTC (défaut "matin")
    const first = rows.map((r) => r.datetimePrevue.getTime()).sort((a, b) => a - b)[0];
    expect(new Date(first!).toISOString()).toBe('2026-06-10T08:00:00.000Z');
  });

  it('borne la fenêtre à dateFin (incluse)', async () => {
    const db = env.handle.db;
    const { officineId, rappelId, userId } = await seedRappel();
    await db.update(rappels).set({ dateFin: '2026-06-12' }).where(eq(rappels.id, rappelId));
    const now = new Date('2026-06-10T09:00:00.000Z');

    const created = await regenerateRappelPrises(db, rappelId, now);

    expect(created).toBe(3); // 10, 11, 12 juin
  });
});
```

(Ajouter `import { eq } from 'drizzle-orm';` en tête du fichier de test.)

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd apps/web && pnpm vitest run test/rappels-reconcile.spec.ts`
Expected: FAIL — `regenerateRappelPrises` non exporté.

- [ ] **Step 3 : Implémenter `regenerateRappelPrises`** (ajouter à `reconcile.ts`)

Mettre à jour l'import en tête de `reconcile.ts` :
`import { prisesPlanifiees, rappels, type Db, type Rappel } from '@piloo/db-schema';`

```ts
/** Fenêtre initiale de génération inline (jours). Identique au POST. */
export const INITIAL_WINDOW_DAYS = 30;

/** Régénère les prises de la fenêtre initiale pour un rappel actif.
 *  N'efface PAS l'existant — le caller appelle cancelFutureRappelPrises
 *  avant si nécessaire. Retourne le nombre de prises insérées. */
export async function regenerateRappelPrises(
  db: Db,
  rappelId: string,
  now: Date = new Date(),
): Promise<number> {
  const [rappel] = await db.select().from(rappels).where(eq(rappels.id, rappelId)).limit(1);
  if (!rappel || rappel.deletedAt || !rappel.actif) return 0;
  const prises = buildInitialRappelPrises(rappel, now);
  if (prises.length === 0) return 0;
  await db.insert(prisesPlanifiees).values(prises);
  return prises.length;
}

/** Calcule (pur) les prises de la fenêtre initiale — extrait du POST. */
export function buildInitialRappelPrises(rappel: Rappel, now: Date = new Date()) {
  const todayUtc = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const debutUtc = new Date(`${rappel.dateDebut}T00:00:00.000Z`);
  const windowStart = debutUtc.getTime() > todayUtc.getTime() ? debutUtc : todayUtc;
  let windowDays = INITIAL_WINDOW_DAYS;
  if (rappel.dateFin) {
    const finUtc = new Date(`${rappel.dateFin}T00:00:00.000Z`);
    const remaining = Math.floor((finUtc.getTime() - windowStart.getTime()) / 86_400_000) + 1;
    if (remaining < windowDays) windowDays = Math.max(0, remaining);
  }
  if (windowDays <= 0) return [];
  return generatePrisesForRappel(rappel, {
    officineId: rappel.officineId,
    windowStart,
    windowDays,
  });
}
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd apps/web && pnpm vitest run test/rappels-reconcile.spec.ts`
Expected: PASS (3 tests).

- [ ] **Step 5 : DRY — le POST réutilise `buildInitialRappelPrises`**

Dans `apps/web/app/api/v1/officines/[officineId]/rappels/route.ts`, remplacer le bloc lignes 91-118 par :

```ts
const prises = buildInitialRappelPrises(rappel);
if (prises.length > 0) {
  await db.insert(prisesPlanifiees).values(prises);
}
```

Et l'import en tête : `import { buildInitialRappelPrises } from '@/lib/rappels/reconcile';` (retirer `generatePrisesForRappel` et la const `INITIAL_WINDOW_DAYS` devenus inutilisés ici).

- [ ] **Step 6 : Vérifier les tests rappels existants**

Run: `cd apps/web && pnpm vitest run test/ -t rappel`
Expected: PASS (POST inchangé fonctionnellement).

- [ ] **Step 7 : Commit**

```bash
git add apps/web/lib/rappels/reconcile.ts apps/web/test/rappels-reconcile.spec.ts apps/web/app/api/v1/officines/[officineId]/rappels/route.ts
git commit -m "feat(rappels): regenerateRappelPrises + DRY génération fenêtre POST (#<num>)"
```

### Task A3 : PATCH réconcilie (pause / réactivation / édition horaires)

**Files:**

- Modify: `apps/web/app/api/v1/rappels/[id]/route.ts`
- Test: `apps/web/test/rappels-reconcile.spec.ts`

- [ ] **Step 1 : Test d'intégration PATCH** (appelle le handler avec un cookie réel via le harnais auth — copier le bloc `beforeAll`/`signup`/`createOfficine` depuis `apps/web/test/prises.spec.ts` en tête du fichier, puis :)

```ts
import { PATCH } from '@/app/api/v1/rappels/[id]/route';

function ctx(id: string) {
  return { params: Promise.resolve({ id }) };
}

describe('PATCH /v1/rappels/{id} réconciliation', () => {
  it('pause (actif=false) → soft-delete les prises futures', async () => {
    const db = env.handle.db;
    const { cookie, officineId, rappelId } = await seedViaApi(); // helper qui crée user+officine+rappel+prises via API/DB
    const res = await PATCH(
      new Request(`${BASE_URL}/api/v1/rappels/${rappelId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie },
        body: JSON.stringify({ actif: false }),
      }),
      ctx(rappelId),
    );
    expect(res.status).toBe(200);
    const futureAlive = await db
      .select()
      .from(prisesPlanifiees)
      .where(and(eq(prisesPlanifiees.rappelId, rappelId), isNull(prisesPlanifiees.deletedAt)));
    expect(futureAlive.filter((p) => p.datetimePrevue >= new Date()).length).toBe(0);
  });

  it('édition horaires (quantité) → régénère les prises futures', async () => {
    // change quantiteSoir : les prises doivent refléter matin + soir
    // ... PATCH { quantite_soir: 1 } puis compter les prises actives par jour = 2
  });
});
```

> `seedViaApi` : helper local qui (1) `signup`, (2) crée l'officine via `POST /v1/officines`, (3) crée le rappel via `POST /v1/officines/{id}/rappels` (génère les prises). Réutiliser les helpers de `prises.spec.ts`.

- [ ] **Step 2 : Lancer, vérifier l'échec** (les prises futures survivent encore)

Run: `cd apps/web && pnpm vitest run test/rappels-reconcile.spec.ts -t "réconciliation"`
Expected: FAIL.

- [ ] **Step 3 : Câbler la réconciliation dans PATCH**

Dans `apps/web/app/api/v1/rappels/[id]/route.ts`, après le `updateRappel(...)` réussi (ligne ~92), ajouter :

```ts
// Réconciliation des prises futures (cf. spec §5). Champs touchant
// la planification : actif, quantités (moments), dates.
const scheduleKeys = [
  'actif',
  'quantite_matin',
  'quantite_midi',
  'quantite_soir',
  'quantite_coucher',
  'date_debut',
  'date_fin',
] as const;
const scheduleChanged = scheduleKeys.some((k) => parsed.data[k] !== undefined);
if (scheduleChanged) {
  const now = new Date();
  await cancelFutureRappelPrises(db, ctx.rappelId, now);
  if (updated.actif) {
    await regenerateRappelPrises(db, ctx.rappelId, now);
  }
}
```

Imports : `import { cancelFutureRappelPrises, regenerateRappelPrises } from '@/lib/rappels/reconcile';`

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd apps/web && pnpm vitest run test/rappels-reconcile.spec.ts`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add apps/web/app/api/v1/rappels/[id]/route.ts apps/web/test/rappels-reconcile.spec.ts
git commit -m "feat(rappels): PATCH réconcilie les prises (pause/édition) (#<num>)"
```

### Task A4 : DELETE annule les prises futures

**Files:**

- Modify: `apps/web/app/api/v1/rappels/[id]/route.ts`
- Test: `apps/web/test/rappels-reconcile.spec.ts`

- [ ] **Step 1 : Test DELETE**

```ts
import { DELETE } from '@/app/api/v1/rappels/[id]/route';

it('DELETE → soft-delete le rappel ET ses prises futures', async () => {
  const db = env.handle.db;
  const { cookie, rappelId } = await seedViaApi();
  const res = await DELETE(
    new Request(`${BASE_URL}/api/v1/rappels/${rappelId}`, {
      method: 'DELETE',
      headers: { cookie },
    }),
    ctx(rappelId),
  );
  expect(res.status).toBe(204);
  const alive = await db
    .select()
    .from(prisesPlanifiees)
    .where(and(eq(prisesPlanifiees.rappelId, rappelId), isNull(prisesPlanifiees.deletedAt)));
  expect(alive.filter((p) => p.datetimePrevue >= new Date()).length).toBe(0);
});
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd apps/web && pnpm vitest run test/rappels-reconcile.spec.ts -t "DELETE"`
Expected: FAIL (prises futures survivent).

- [ ] **Step 3 : Câbler dans DELETE**

Dans le handler `DELETE` de `route.ts`, après `softDeleteRappel(db, ctx.rappelId)` réussi :

```ts
await cancelFutureRappelPrises(db, ctx.rappelId);
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd apps/web && pnpm vitest run test/rappels-reconcile.spec.ts`
Expected: PASS (tous).

- [ ] **Step 5 : Lint + typecheck + commit**

```bash
cd apps/web && pnpm lint && pnpm type-check
git add apps/web/app/api/v1/rappels/[id]/route.ts apps/web/test/rappels-reconcile.spec.ts
git commit -m "feat(rappels): DELETE annule les prises futures (#<num>)"
```

---

## Phase B — Mobile (Flutter)

### Task B1 : Mutations provider (update / delete / toggle)

**Files:**

- Modify: `apps/mobile/lib/features/rappels/data/rappels_provider.dart`

- [ ] **Step 1 : Ajouter les fonctions** (suivre le style de `createRappel` déjà dans ce fichier — invalidations identiques)

```dart
/// PATCH /v1/rappels/{id}. Invalide la liste + la timeline (les prises
/// sont régénérées côté serveur). Lève en cas d'échec.
Future<Rappel> updateRappel(
  WidgetRef ref, {
  required String id,
  required String officineId,
  String? nomTexte,
  String? unite,
  int? quantiteMatin,
  int? quantiteMidi,
  int? quantiteSoir,
  int? quantiteCoucher,
  Date? dateDebut,
  Date? dateFin,
  bool? actif,
  String? notes,
}) async {
  final api = ref.read(pilooApiClientProvider).getRappelsApi();
  final builder = UpdateRappelInputBuilder()
    ..nomTexte = nomTexte
    ..unite = unite
    ..quantiteMatin = quantiteMatin
    ..quantiteMidi = quantiteMidi
    ..quantiteSoir = quantiteSoir
    ..quantiteCoucher = quantiteCoucher
    ..dateDebut = dateDebut
    ..dateFin = dateFin
    ..actif = actif
    ..notes = notes;
  final res = await api.v1RappelsIdPatch(id: id, updateRappelInput: builder.build());
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('Modification rappel : statut ${res.statusCode}');
  }
  ref.invalidate(rappelsProvider(officineId));
  ref.invalidate(prisesDayProvider);
  return res.data!;
}

/// Raccourci pause/réactivation.
Future<Rappel> toggleRappelActif(
  WidgetRef ref, {
  required String id,
  required String officineId,
  required bool actif,
}) =>
    updateRappel(ref, id: id, officineId: officineId, actif: actif);

/// DELETE /v1/rappels/{id} (soft-delete serveur).
Future<void> deleteRappel(
  WidgetRef ref, {
  required String id,
  required String officineId,
}) async {
  final api = ref.read(pilooApiClientProvider).getRappelsApi();
  final res = await api.v1RappelsIdDelete(id: id);
  if (res.statusCode != 204 && res.statusCode != 200) {
    throw Exception('Suppression rappel : statut ${res.statusCode}');
  }
  ref.invalidate(rappelsProvider(officineId));
  ref.invalidate(prisesDayProvider);
}
```

> Vérifier les noms exacts du client généré : `getRappelsApi()`, `v1RappelsIdPatch`, `v1RappelsIdDelete`, `UpdateRappelInputBuilder` (cf. `apps/mobile/lib/gen/openapi/lib/src/api/rappels_api.dart`). Si l'API générée ne contient pas encore PATCH/DELETE, régénérer le client : `pnpm openapi:generate` à la racine puis builder Dart.

- [ ] **Step 2 : Analyse Dart**

Run: `cd apps/mobile && dart analyze lib/features/rappels`
Expected: 0 erreur.

- [ ] **Step 3 : Commit**

```bash
git add apps/mobile/lib/features/rappels/data/rappels_provider.dart
git commit -m "feat(rappels mobile): mutations update/delete/toggle (#<num>)"
```

### Task B2 : Route `rappels`

**Files:**

- Modify: `apps/mobile/lib/core/router/routes.dart`
- Modify: `apps/mobile/lib/core/router/router.dart`

- [ ] **Step 1 : Déclarer la route** dans `routes.dart` (à côté de `ordonnances`)

```dart
// dans class RouteName : après `static const ordonnances = 'ordonnances';`
static const rappels = 'rappels';
// dans class RoutePath : après `static const ordonnances = '/ordonnances';`
static const rappels = '/rappels';
```

- [ ] **Step 2 : Ajouter la route go_router** dans `router.dart` (mêmes options que la route `ordonnances` — push sans tab bar). Importer `rappels_screen.dart` puis ajouter :

```dart
GoRoute(
  path: RoutePath.rappels,
  name: RouteName.rappels,
  builder: (context, state) => const RappelsScreen(),
),
```

- [ ] **Step 3 : Analyse** (échouera tant que `RappelsScreen` n'existe pas — créé en B3)

Run: `cd apps/mobile && dart analyze lib/core/router`
Expected: erreur "RappelsScreen undefined" (résolue en B3). Ne pas committer seul — committer avec B3.

### Task B3 : `RappelsScreen` (liste + actions)

**Files:**

- Create: `apps/mobile/lib/features/rappels/presentation/rappels_screen.dart`

- [ ] **Step 1 : Créer l'écran.** Structure (suivre le style cartes de `more_screen.dart` : `PilooScreenHeader`, sections `PilooColors.surface` + border) :
  - `ConsumerWidget`, header `PilooScreenHeader(title: 'Mes rappels')`.
  - Lire l'officine active : `ref.watch(activeOfficineProvider)` → `officineId`.
  - `ref.watch(rappelsProvider(officineId))` → `AsyncValue<List<Rappel>>` : loading (spinner), error (message + retry), data.
  - Tri : `actif` d'abord puis par `nomTexte`.
  - Empty state : « Aucun rappel — crée-en un depuis une boîte de ton inventaire. » + bouton vers l'inventaire (`context.goNamed(RouteName.inventory)` ou équivalent).
  - Carte par rappel : `nomTexte` (Fraunces), résumé horaires (helper `_horairesSummary(rappel)` → « Matin 1 · Soir 2 »), période (`_periodeLabel(rappel)`), pastille statut (`Actif` vert / `En pause` gris), `Switch` (pause/réactivation) → `toggleRappelActif`, tap carte → `showRappelFormSheet(...)` en mode édition (Task B5), action supprimer (icône poubelle → `showDialog` confirmation → `deleteRappel`).
  - Masquer Switch / supprimer / édition si le rôle est `viewer` (lire le rôle via `rappelsProvider` n'expose pas le rôle ; récupérer le rôle depuis `officinesListProvider` ou `activeOfficineProvider` selon ce qui porte `role`).

```dart
// Helper résumé horaires — exact, à inclure dans le fichier.
String _horairesSummary(Rappel r) {
  final parts = <String>[];
  if (r.quantiteMatin != null) parts.add('Matin ${r.quantiteMatin}');
  if (r.quantiteMidi != null) parts.add('Midi ${r.quantiteMidi}');
  if (r.quantiteSoir != null) parts.add('Soir ${r.quantiteSoir}');
  if (r.quantiteCoucher != null) parts.add('Coucher ${r.quantiteCoucher}');
  return parts.join(' · ');
}
```

> Confirmation suppression : utiliser un `AlertDialog` Flutter standard (PAS les browser dialogs). Texte : « Supprimer ce rappel ? Les prises à venir seront retirées. »

- [ ] **Step 2 : Analyse Dart**

Run: `cd apps/mobile && dart analyze lib/features/rappels lib/core/router`
Expected: 0 erreur.

- [ ] **Step 3 : Commit (route + écran ensemble)**

```bash
git add apps/mobile/lib/core/router/routes.dart apps/mobile/lib/core/router/router.dart apps/mobile/lib/features/rappels/presentation/rappels_screen.dart
git commit -m "feat(rappels mobile): écran Mes rappels + route (#<num>)"
```

### Task B4 : Entrée « Mes rappels » dans Plus

**Files:**

- Modify: `apps/mobile/lib/features/more/presentation/more_screen.dart:65-82`

- [ ] **Step 1 : Ajouter la ligne** dans `_monAppRows`, juste après la row `Ordonnances` :

```dart
const _Row(
  icon: PhosphorIconsRegular.bell,
  label: 'Mes rappels',
  routeName: RouteName.rappels,
),
```

- [ ] **Step 2 : Analyse + commit**

```bash
cd apps/mobile && dart analyze lib/features/more
git add apps/mobile/lib/features/more/presentation/more_screen.dart
git commit -m "feat(rappels mobile): entrée 'Mes rappels' dans Plus (#<num>)"
```

### Task B5 : Mode édition du formulaire rappel

**Files:**

- Modify: `apps/mobile/lib/features/rappels/presentation/rappel_quick_sheet.dart`
- Modify: `apps/mobile/lib/features/rappels/presentation/rappels_screen.dart` (brancher l'édition)

- [ ] **Step 1 : Étendre `showRappelQuickSheet`** pour accepter un rappel initial optionnel + notes :

```dart
Future<RappelQuickResult?> showRappelQuickSheet(
  BuildContext context, {
  required String medicamentName,
  String suggestedUnite = 'comprimé',
  Rappel? initial, // null = création ; non-null = édition (pré-remplissage)
}) { /* passe `initial` au _RappelQuickSheet */ }
```

Dans `_RappelQuickSheetState.initState`, si `initial != null` : pré-remplir `_matin/_midi/_soir/_coucher` depuis `initial.quantite*`, `_duree` déduit de `initial.dateFin` (sinon `aVie`), et ajouter un champ notes (`TextField` contrôlé). Le bouton primaire affiche « Enregistrer » en édition (vs « Créer le rappel »). `RappelQuickResult` gagne un champ `String? notes`.

- [ ] **Step 2 : Brancher dans `RappelsScreen`** : au tap d'une carte, ouvrir la sheet en mode édition puis appeler `updateRappel(...)` avec le résultat (mapper `RappelDuree` → `dateFin`, `dateDebut` inchangée).

- [ ] **Step 3 : Vérifier la création inchangée** (l'inventaire appelle toujours `showRappelQuickSheet` sans `initial`).

Run: `cd apps/mobile && dart analyze lib/features/rappels lib/features/inventory`
Expected: 0 erreur.

- [ ] **Step 4 : Commit**

```bash
git add apps/mobile/lib/features/rappels/presentation/rappel_quick_sheet.dart apps/mobile/lib/features/rappels/presentation/rappels_screen.dart
git commit -m "feat(rappels mobile): édition d'un rappel (form pré-rempli) (#<num>)"
```

---

## Phase C — Web (Next.js)

### Task C1 : Entrée sidebar « Rappels »

**Files:**

- Modify: `apps/web/components/app/sidebar.tsx:23-29`

- [ ] **Step 1 : Ajouter à `NAV_TOP`** après l'entrée Ordonnances :

```ts
{ href: '/rappels', label: 'Rappels' },
```

- [ ] **Step 2 : Commit** (la page arrive en C2 ; le lien 404 entre-temps est acceptable sur la branche)

```bash
git add apps/web/components/app/sidebar.tsx
git commit -m "feat(rappels web): entrée sidebar Rappels (#<num>)"
```

### Task C2 : Page `/rappels` (liste + pause + suppression)

**Files:**

- Create: `apps/web/app/(app)/rappels/page.tsx`

- [ ] **Step 1 : Créer la page** (client component, suivre le pattern de `app/(app)/inventory/page.tsx` pour `$api` + `useActiveOfficine`).

```tsx
'use client';

import { $api, type components } from '@piloo/api-client';
import { useState } from 'react';

import { RappelFormDialog } from '@/components/app/rappels/rappel-form-dialog';
import { useActiveOfficine } from '@/lib/officines/active-officine';

type Rappel = components['schemas']['Rappel'];

function horairesSummary(r: Rappel): string {
  const p: string[] = [];
  if (r.quantite_matin != null) p.push(`Matin ${r.quantite_matin}`);
  if (r.quantite_midi != null) p.push(`Midi ${r.quantite_midi}`);
  if (r.quantite_soir != null) p.push(`Soir ${r.quantite_soir}`);
  if (r.quantite_coucher != null) p.push(`Coucher ${r.quantite_coucher}`);
  return p.join(' · ');
}

export default function RappelsPage() {
  const { activeOfficineId } = useActiveOfficine();
  const queryClient = /* useQueryClient() from @tanstack/react-query */;
  const { data, isLoading, error } = $api.useQuery(
    'get', '/v1/officines/{officineId}/rappels',
    { params: { path: { officineId: activeOfficineId ?? '' } } },
    { enabled: !!activeOfficineId },
  );
  // patch + delete mutations via $api.useMutation('patch'|'delete', '/v1/rappels/{id}')
  // invalider la query liste + les queries /v1/prises au succès.
  // Rendu : titre, état vide, liste de lignes (nom, horairesSummary, période,
  // pastille statut, switch pause, bouton Modifier → RappelFormDialog, bouton
  // Supprimer → confirm window.confirm puis mutation delete).
  // ...
}
```

> Détails : mutations `$api.useMutation('patch', '/v1/rappels/{id}')` et `('delete', '/v1/rappels/{id}')`. Sur succès, `queryClient.invalidateQueries()` sur la liste rappels et les prises. Confirmation suppression via `window.confirm` (acceptable côté web app) ou un petit dialog shadcn si présent.

- [ ] **Step 2 : Lancer le dev server et vérifier**

Run: `cd apps/web && pnpm dev` puis ouvrir `/rappels` connecté.
Expected: la liste s'affiche ; pause/suppression fonctionnent et la timeline reflète le changement.

- [ ] **Step 3 : type-check + commit**

```bash
cd apps/web && pnpm type-check
git add apps/web/app/(app)/rappels/page.tsx
git commit -m "feat(rappels web): page Mes rappels (liste/pause/suppression) (#<num>)"
```

### Task C3 : Dialog création/édition

**Files:**

- Create: `apps/web/components/app/rappels/rappel-form-dialog.tsx`

- [ ] **Step 1 : Créer le dialog** (champs : quantités matin/midi/soir/coucher avec inputs numériques, unité, date_debut/date_fin, notes). En mode édition, pré-remplir depuis le `Rappel` ; submit → `$api.useMutation('patch', '/v1/rappels/{id}')`. Suivre le style de `components/app/inventory/add-boite-dialog.tsx` (Dialog shadcn + React Hook Form + Zod si utilisé là-bas).

- [ ] **Step 2 : Brancher** depuis `page.tsx` (bouton « Modifier » sur chaque ligne ouvre le dialog).

- [ ] **Step 3 : type-check + lint + commit**

```bash
cd apps/web && pnpm type-check && pnpm lint
git add apps/web/components/app/rappels/rappel-form-dialog.tsx apps/web/app/(app)/rappels/page.tsx
git commit -m "feat(rappels web): dialog édition d'un rappel (#<num>)"
```

---

## Finalisation

- [ ] **Step 1 : Tests + lint + typecheck globaux**

```bash
# racine
pnpm turbo lint type-check
cd apps/web && pnpm vitest run
cd ../mobile && dart analyze
```

- [ ] **Step 2 : Vérif manuelle bout-en-bout** (web + mobile) : créer un rappel depuis l'inventaire → il apparaît dans « Mes rappels » → pause (disparaît de la timeline) → réactive (réapparaît) → édite les horaires (timeline mise à jour) → supprime (disparaît partout).

- [ ] **Step 3 : PR**

```bash
git push -u origin feat/<num>-gestion-rappels
gh pr create --repo my-monkeys/piloo --base main --fill --body "Closes #<num>"
```

---

## Notes / risques

- **Client OpenAPI Dart** : si `v1RappelsIdPatch`/`v1RappelsIdDelete` ou `UpdateRappelInputBuilder` n'existent pas encore dans `apps/mobile/lib/gen/openapi`, régénérer le client (le contrat backend les déclare déjà — cf. `UpdateRappelInputSchema`). Faire cette régénération en préalable de Task B1.
- **Web `$api`** : ce plan suppose le fix #353 (préfixe `/api`) mergé. Sinon les requêtes web 404. Vérifier que `main` contient le fix avant de tester la Phase C (sinon rebaser sur la branche du fix).
- **Sliding-gen rappels** : il n'existe pas de cron de génération glissante pour les rappels (seulement prescriptions). La régénération couvre la fenêtre initiale (30j). Étendre la génération glissante aux rappels est hors scope (suivi séparé).
- **Rôle viewer** : l'API impose déjà owner/editor sur PATCH/DELETE ; l'UI masque les actions pour les viewers (défense en profondeur, pas de blocage dur nécessaire).
