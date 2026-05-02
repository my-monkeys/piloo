# Instructions Claude Code — Piloo

Ce fichier est lu automatiquement par Claude Code. Il donne le contexte global du projet. Les sous-dossiers `apps/web/`, `apps/mobile/`, `packages/*/` ont leur propre `CLAUDE.md` pour le contexte spécifique.

## Nature du projet

Piloo est un **carnet numérique de médicaments** pour la maison, avec un pont léger patient↔pro.

**Périmètre produit**
- Gestion d'une "officine domestique" : scan des boîtes, inventaire, dates de péremption, regroupement par molécule (DCI).
- Timeline de prises avec notifications (push, email, SMS).
- Partage entre utilisateurs avec 3 rôles : Propriétaire / Éditeur / Lecteur.
- Compte pro de santé pour suivre plusieurs patients.

**Ce que l'app n'est PAS** (important pour tes décisions)
- Ce n'est PAS un dispositif médical au sens MDR.
- Ce n'est PAS un outil de validation clinique d'ordonnance.
- Ce n'est PAS un substitut à l'ordonnance officielle.
- C'est un **carnet de suivi personnel**, un meilleur cahier. On enregistre ce qui a été prescrit ailleurs, on ne prescrit pas.

Si tu écris du texte visible par l'utilisateur (UI, CGU, onboarding), cette distinction doit rester claire. Phrase-type à utiliser : *"Ce carnet numérique est un aide-mémoire personnel. Il ne remplace ni votre ordonnance, ni l'avis de votre médecin ou pharmacien."*

## Stack technique (non-négociable)

- **Mobile** : Flutter 3.x + Dart. Pas de React Native.
- **Web** : Next.js 15 (App Router) + TypeScript. Pas de Pages Router.
- **Backend** : API Routes Next.js + validation Zod + OpenAPI généré.
- **DB serveur** : PostgreSQL + Drizzle ORM.
- **DB mobile locale** : SQLite + Drift.
- **Sync offline** : custom (pattern append-only operations log + last-write-wins). PAS de PowerSync, PAS d'Electric SQL, PAS de Firebase Firestore.
- **Monorepo** : Turborepo pour le JS/TS, Flutter vit à côté (son propre tooling).
- **Auth** : Better Auth ou Clerk (à trancher en M1).
- **Notifications** : Firebase Cloud Messaging (push) + Brevo (email/SMS).

Si une tâche te pousse à proposer une autre techno dans cette liste, arrête-toi et demande confirmation à l'utilisateur avant de coder.

## Principes de développement

1. **Offline-first côté mobile**. Toute écriture locale doit passer par la file `pending_operations`. Ne jamais supposer que le réseau est disponible.
2. **Source de vérité contractuelle = Zod côté backend**. Les types TS et Dart sont générés depuis OpenAPI. Ne jamais écrire un modèle Dart à la main si un endpoint existe.
3. **Soft delete partout**. Pas de DELETE réel sur les tables métier, toujours `deleted_at`. Nécessaire pour la sync multi-device.
4. **Pas de données sensibles en clair dans les logs**. Pas de CIP, pas de noms de médicaments, pas de dates de prise. Tout log concernant un patient doit être anonymisé.
5. **i18n dès le départ** côté texte utilisateur (au moins FR, mais via un système de clés). Même si le MVP est FR only, ne jamais hardcoder de string visible.
6. **Tests** : tests unitaires sur la logique métier (sync, parsing GS1, matching BDPM). Pas de course aux tests UI au MVP, focus sur ce qui casserait fort.
7. **Responsabilité utilisateur** : toute action destructive (marquer vide, supprimer boîte, révoquer partage) demande confirmation explicite.

## Base de données médicaments (BDPM)

La base BDPM (Base de Données Publique des Médicaments) est la source officielle française, gratuite, mise à jour 2×/jour via data.gouv.fr. Voir `docs/architecture.md` pour les détails d'intégration.

Deux niveaux d'utilisation :
- **Côté serveur** : import des TSV BDPM dans Postgres (table `medicaments_bdpm`, read-only).
- **Côté mobile** : SQLite embarqué, généré depuis la base serveur, téléchargé au premier lancement + diff mensuel. Permet la résolution CIP → nom/DCI/dosage **totalement offline**.

## Sécurité & confidentialité

- **RGPD** s'applique : consentement, minimisation, droit à l'effacement.
- **HDS (Hébergement Données de Santé)** : ignoré pour le POC, **obligatoire avant toute prod commerciale**. Ne pas prétendre être HDS-compliant tant qu'on ne l'est pas.
- **Pas de tracking tiers** (Google Analytics, Mixpanel…) sur les écrans où figurent des données médicales.
- **Chiffrement en transit** : HTTPS partout, y compris en dev si possible.
- **Secrets** : jamais dans le repo, toujours via variables d'environnement. Un `.env.example` documente les clés attendues.

## Conventions de code

- **TypeScript** : strict mode activé, pas de `any` sans commentaire justificatif.
- **Dart** : `dart format` + `dart analyze` propres avant commit.
- **Commits** : convention Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`).
- **Branches** : `main` protégée, features en branches `feat/nom-feature`.
- **Pas de PR sans passage du lint** (`eslint` + `prettier` côté JS/TS, `dart analyze` côté Flutter).

## Workflow GitHub Project (tickets)

Le travail est découpé en **tickets GitHub** organisés dans un GitHub Project. C'est la **source de vérité** de ce qui est à faire, dans quel ordre, et par qui. Plusieurs personnes (humains + agents) bossent dessus en parallèle — respecter ce workflow est non-négociable pour éviter les collisions.

### Règle d'or

**Pas de code sans ticket.** Si tu te lances sur quelque chose qui n'a pas de ticket, arrête-toi et demande s'il faut en créer un.

### Cycle de vie d'un ticket

À chaque fois que tu prends du travail :

1. **Choisir le prochain ticket** — prends le ticket en haut de la colonne `Todo` du Project (ordre = priorité). Ne saute pas la file sans raison explicite.
2. **S'assigner le ticket** (`gh issue edit <num> --add-assignee @me`) pour signaler que tu le prends. Si quelqu'un est déjà assigné ou que le ticket est déjà `In Progress`, **ne le prends pas** — choisis le suivant.
3. **Passer le ticket en `In Progress`** dans le Project board avant de commencer à coder.
4. **Créer une branche dédiée** liée au ticket : `gh issue develop <num> --checkout` (crée la branche, l'attache au ticket et la checkout). Sinon nommer manuellement `feat/<num>-slug-court` / `fix/<num>-...`.
5. **Commits** : référencer le ticket dans le message (`feat: ajoute X (#<num>)`). Ça crée automatiquement le lien dans GitHub.
6. **PR** : ouvrir une PR avec `Closes #<num>` dans la description pour fermer auto le ticket au merge. La PR doit aussi être liée au ticket dans le Project (en général auto si `Closes #` est présent).
7. **Commenter le ticket** avant de passer en Done : un court résumé (3-5 lignes) de **ce qui a été fait**, des décisions notables, et des éventuels follow-ups. Lier explicitement le ou les commits / la PR si le lien auto n'a pas marché.
8. **Passer en `Done`** seulement après merge de la PR (ou commit sur `main` si workflow direct accepté pour le ticket).

### Commandes `gh` utiles

```bash
gh issue list --assignee @me --state open       # mes tickets en cours
gh issue view <num>                             # détails d'un ticket
gh issue edit <num> --add-assignee @me          # s'assigner
gh issue develop <num> --checkout               # branche liée + checkout
gh issue comment <num> --body "..."             # ajouter un commentaire
gh pr create --fill                             # PR avec titre/body depuis les commits
```

Pour bouger un ticket entre colonnes du Project, utiliser `gh project item-edit` ou l'UI GitHub si plus rapide.

### Multi-personnes / multi-agents

- **Toujours regarder qui est assigné** avant de toucher à un ticket.
- **Un seul ticket `In Progress` à la fois** par personne/agent. Si tu dois en abandonner un, repasse-le en `Todo`, retire-toi des assignés, et commente pourquoi.
- **Pas de force-push sur une branche partagée**. Si quelqu'un d'autre a poussé entre-temps : `git pull --rebase` proprement.
- En cas de doute (ticket flou, dépendance bloquante, scope qui dérive), **commenter le ticket** plutôt que d'avancer en aveugle.

## Workflow avec Claude Code

Quand tu bosses dans ce repo :

1. **Lis toujours le CLAUDE.md du dossier le plus proche** avant d'écrire du code.
2. **Suis le workflow GitHub Project ci-dessus** — choisis un ticket, assigne-toi, passe en `In Progress`, code, commente, passe en `Done`.
3. **Propose un plan avant d'implémenter une grosse feature** — ne te lance pas direct sur 500 lignes.
4. **Respecte la stack** (cf. section ci-dessus). Pas de librairie exotique sans demander.
5. **Teste localement avant de pusher** si c'est possible dans ton environnement.
6. **Documente les décisions techniques significatives** dans `docs/architecture.md` (sous forme d'ADR court : contexte, décision, conséquences).

## Documentation à lire en priorité

- `docs/dossier-cadrage.md` — vision produit, personas, priorités, positionnement
- `docs/spec.md` — spécifications fonctionnelles détaillées
- `docs/architecture.md` — décisions techniques + patterns (sync, OpenAPI)
- `docs/data-model.md` — tables, relations, invariants
- `docs/api-contract.md` — conventions REST + exemples
- `docs/ui-ux-guidelines.md` — direction design, écrans à concevoir
- `docs/roadmap.md` — priorisation M1-M3

## Questions fréquentes que tu peux te poser

**Q : Je vois une feature pas encore dans le code, dois-je la coder ?**
R : Vérifie d'abord dans `docs/roadmap.md` si elle est prévue pour la phase courante. Sinon demande.

**Q : L'utilisateur me demande d'utiliser React Native.**
R : Explique que la stack est Flutter pour le mobile (raison : éviter le churn Expo/RN que l'utilisateur ne veut pas gérer). Demande confirmation avant de dévier.

**Q : L'utilisateur me demande d'ajouter un suivi analytics / tracking.**
R : Alerte d'abord sur le positionnement privacy-first et le RGPD (données de santé). Propose des alternatives (analytics self-hosted type Plausible, ou rien du tout).

**Q : On me demande d'implémenter une règle clinique (alerte interaction médicamenteuse…).**
R : Refuse. Ça nous fait passer dispositif médical (marquage CE obligatoire, règlement MDR). On reste carnet de suivi, on ne fait AUCUNE recommandation clinique.

---

## Bonnes pratiques de code

- **Clean code** : noms explicites, fonctions courtes (< 30 lignes), une responsabilité.
- **Pas d'abstraction prématurée** — on n'extrait qu'au 3ᵉ usage.
- **Pas de commentaires "quoi"** — commenter le **pourquoi** non évident (en particulier les décisions liées à la non-classification dispositif médical).
- **Valider aux frontières** : Zod côté API Routes, validation côté Drift sur mobile.
- **Pas de feature flags/dead code "au cas où"** — on supprime, on ne désactive pas.
- **Format / lint / type-check** avant chaque commit (`turbo lint` + `turbo type-check` à la racine).

## Architecture (rappels)

- Garder les fichiers sous **~500 lignes**.
- **Source de vérité** = schéma Zod côté backend → types TS et Dart générés depuis OpenAPI. Pas de modèle écrit à la main si l'endpoint existe.
- **Offline-first mobile** : toute écriture passe par `pending_operations`. Pas de hypothèse "le réseau est disponible".
- Séparer **packages partagés** (`db-schema`, `api-contract`) des **apps** (`apps/web`, `apps/mobile`). Voir le `CLAUDE.md` de chaque sous-package pour le contexte spécifique.

## Git workflow

- **Une feature = une branche** : `feat/...`, `fix/...`, `chore/...`, `refactor/...`.
- **Commits réguliers** à chaque palier fonctionnel cohérent.
- **Conventional Commits** : `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `test:`.
- Jamais de commit "WIP" sur `main`. Branche perso pour sauvegarder en cours.
- `git pull --rebase` pour les branches courtes.
- **Pas de secrets** dans les commits — `.env*` dans `.gitignore`.
- Avant push : `git status` + `git diff --staged`.
