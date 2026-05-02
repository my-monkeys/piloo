# Contribuer à Piloo

Merci de prendre le temps de contribuer. Ce document décrit le workflow attendu pour proposer une modification du code, qu'elle vienne d'un humain ou d'un agent.

Pour le contexte produit et la stack, voir [`README.md`](./README.md) et [`CLAUDE.md`](./CLAUDE.md). Pour les décisions techniques, voir [`docs/architecture.md`](./docs/architecture.md) et les ADRs dans [`docs/adr/`](./docs/adr/).

## Pré-requis

- **Node.js ≥ 20.10**
- **pnpm ≥ 10** (utiliser la version pinnée dans [`package.json#packageManager`](./package.json))
- **Flutter 3.x** si tu touches à `apps/mobile`
- **Docker** (optionnel, pour `docker compose up` qui lance Postgres en local sur le port 5433)

```bash
pnpm install              # installe les deps + active les hooks husky via le script `prepare`
docker compose up -d      # démarre Postgres dev (facultatif, les tests unitaires n'en ont pas besoin)
cp .env.example .env      # documenter les vars manquantes au fur et à mesure
```

## Workflow ticket → branche → PR

Le travail est piloté par le **GitHub Project "Piloo MVP"**. Tout changement de code passe par un ticket. Si tu te lances sur quelque chose qui n'a pas de ticket, **arrête-toi et crée-en un** ou demande confirmation.

1. **Choisir** un ticket en haut de la colonne `Todo` du Project (l'ordre = priorité).
2. **S'assigner** le ticket : `gh issue edit <num> --add-assignee @me`. S'il est déjà assigné ou `In Progress`, prends le suivant.
3. **Passer en `In Progress`** dans le board (UI ou `gh project item-edit`).
4. **Créer la branche** : `gh issue develop <num> --base main --name <prefix>/<num>-<slug> --checkout`. Préfixes : `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, `test/`, `ci/`.
5. **Commits** : référence le ticket dans le message (`feat: ajoute X (#<num>)`). Plusieurs petits commits cohérents valent mieux qu'un gros commit fourre-tout.
6. **PR** : `gh pr create --base main --title ... --body "Closes #<num>"`. Le `Closes #<num>` ferme automatiquement le ticket au merge.
7. **Commenter le ticket** avant de passer en `Done` : 3-5 lignes résumant ce qui a été fait, les décisions notables, les éventuels follow-ups.
8. **Merger** une fois la CI verte (squash recommandé : `gh pr merge --squash --delete-branch`).

> **Un seul ticket `In Progress` à la fois** par personne / agent. Si tu dois en abandonner un, retire-toi des assignés et repasse-le en `Todo`.

## Conventional Commits

Tous les commits doivent suivre la [convention Conventional Commits](https://www.conventionalcommits.org/). Le hook `commit-msg` (commitlint) refuse les messages non conformes.

Types acceptés : `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `ci`, `style`, `perf`, `build`, `revert`.

Exemples :

```
feat(auth): ajoute le flow de mot de passe oublié (#63)
fix(sync): évite la double-écriture quand le serveur renvoie 409 (#94)
chore(infra): déplace tsconfig.base à la racine
```

## Hooks pre-commit

`pnpm install` active automatiquement les hooks via `husky`. Deux hooks tournent :

- **commit-msg** → `commitlint` valide le format du message.
- **pre-commit** → `lint-staged` lance `eslint --fix` + `prettier --write` sur les fichiers stagés (TS/JS/MJS/JSX) et `prettier --write` sur les autres formats lisibles (JSON, MD, YAML, CSS).

Le typecheck complet n'est **pas** lancé en pre-commit (trop lent quand le projet grossit) — il est fait par la CI.

## Avant de pousser

Lance localement :

```bash
pnpm lint           # eslint + prettier (root + workspaces)
pnpm typecheck      # tsc --noEmit (root + workspaces)
pnpm test           # vitest run (root + workspaces)
```

Si tu touches aux schémas Zod / OpenAPI :

```bash
pnpm openapi:generate   # régénère openapi.yaml + clients TS + Dart
```

Et commite les fichiers générés (la CI vérifie qu'ils sont à jour via `pnpm openapi:check`).

## Conventions de code

Voir [`CLAUDE.md` §"Bonnes pratiques de code"](./CLAUDE.md) pour le détail. En résumé :

- **Clean code** : noms explicites, fonctions courtes (< 30 lignes), une responsabilité.
- **Pas d'abstraction prématurée** — on n'extrait qu'au 3ᵉ usage.
- **Pas de commentaires "quoi"** — commenter le **pourquoi** non évident.
- **Valider aux frontières** : Zod côté API Routes, validation Drift sur mobile.
- **Pas de feature flags / dead code "au cas où"** — on supprime, on ne désactive pas.
- **TypeScript strict** : pas de `any` sans justification ; respect de `noUncheckedIndexedAccess`.
- **Soft delete partout** côté DB serveur (`deleted_at`), nécessaire pour la sync multi-device.
- **i18n dès le départ** — pas de string visible utilisateur en dur.

## Données sensibles

Piloo manipule des données de santé. **Aucune** des éléments suivants ne doit apparaître dans les logs ou les commits :

- Codes CIP, noms de médicaments, dosages d'un patient identifié
- Dates de prises, planning, notes d'ordonnance
- Identifiants utilisateurs en clair (utiliser des hashes courts ou IDs anonymisés)

Les fichiers `.env*` sont dans `.gitignore` et **ne doivent jamais être committés**. Si tu ajoutes une variable d'environnement, ajoute la clé (sans valeur) dans `.env.example`.

## Tests

- **Unitaires** : Vitest pour TS (`*.test.ts` à côté de la source ou dans `tests/`), `flutter test` pour Dart.
- **Périmètre prioritaire** : sync (push/pull, conflits), parser GS1, matching BDPM, génération de prises, RBAC.
- **Pas de course aux tests UI** au MVP — focus sur la logique métier qui peut casser fort.

## Branches & rebase

- `main` est la branche par défaut. Pas de commit direct dessus en prod (la protection est attendue ; pour l'instant on s'auto-discipline).
- Branches courtes → `git pull --rebase origin main` régulièrement pour rester à jour.
- **Pas de force-push** sur une branche partagée. Si tu pousses sur ta propre branche feature isolée, OK avec parcimonie.

## Questions ouvertes

Pour discuter d'une décision (lib, architecture, scope), commente le ticket ou ouvre un ADR dans [`docs/adr/`](./docs/adr/) en suivant le format des ADRs existants (contexte, options, décision, conséquences).

Bon code 🚀
