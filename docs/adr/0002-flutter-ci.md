# ADR 001 — Flutter CI : Codemagic vs GitHub Actions + fastlane

- **Statut** : Accepté
- **Date** : 2026-05-02
- **Décideur** : Swarm Infrastructure (worker #8)
- **Périmètre** : pipeline de build mobile (`apps/mobile`, Flutter iOS + Android). Backend/web restent sur GitHub Actions.

## Contexte

`docs/architecture.md` §Tooling laisse ouvert le choix entre **Codemagic** et **GitHub Actions + fastlane** pour les builds Flutter (iOS / Android, upload TestFlight + Play Console internal track).

Contraintes spécifiques à Piloo :

- Équipe très réduite (solo dev + agents) au MVP, pas d'expertise iOS interne.
- Cadence M1/M2 : 1–2 builds mobile par jour en moyenne, pics avant releases beta.
- Backend / web déjà sur **GitHub Actions** (déploiement Vercel, lint, tests). Ce choix-là n'est pas remis en cause.
- Les builds mobile sont **indépendants** des pipelines backend/web : pas de chaînage cross-stack à orchestrer.
- Pas de Mac dédié pour build local iOS reproductible → la CI doit fournir des runners macOS.
- Signing iOS = friction historique (provisioning profiles, App Store Connect API key, certificats partagés entre runners).
- Aucune contrainte HDS sur le pipeline lui-même (pas de données patient en jeu, juste des artefacts).

## Options évaluées

### Option A — Codemagic

CI/CD géré, spécialisé Flutter.

- **+ Free tier** : 500 min/mois sur runners M1 (largement au-dessus du besoin MVP estimé à ~150–250 min/mois).
- **+ Signing iOS quasi clé-en-main** : intégration App Store Connect API, auto-provisioning, gestion des certificats via leur vault.
- **+ Upload TestFlight & Play Console** built-in (étapes nommées, pas de Ruby à maintenir).
- **+** Détection Flutter native, cache `pub`/Gradle géré, web UI pour relancer / voir les logs.
- **+** Configuration : un seul `codemagic.yaml` + secrets dans leur UI → pipeline fonctionnel en ~1 h.
- **−** Lock-in modéré (le YAML n'est pas portable tel quel vers GHA).
- **−** Coût au-delà du free tier : ~0,038 $/min M1 (≈ 20 $/mois si on double l'usage estimé).
- **−** Plateforme CI supplémentaire à connaître / surveiller (en plus de GHA).
- **−** Pas de status checks GitHub aussi riches que les workflows GHA natifs (mais l'intégration PR existe).

### Option B — GitHub Actions + fastlane

Tout sur GHA, fastlane pour l'orchestration des étapes iOS / Android.

- **+** **Cohérence** : un seul CI pour backend, web, mobile. Secrets, status checks, audit log centralisés.
- **+** Pas de plateforme tierce à introduire.
- **+** fastlane est l'**industry standard** : énorme communauté, ecosystème (`match`, `pilot`, `supply`, `gym`).
- **+** Contrôle complet sur les étapes (utile si on veut intégrer scan SBOM, signature de notes de release, etc.).
- **−** **Coût macOS** sur GHA repo privé : multiplicateur ×10 sur les minutes (free tier 2 000 min ≡ 200 min macOS/mois). Au-delà : ~0,08 $/min, soit **~2× le prix de Codemagic** pour un build M1.
- **−** Setup signing iOS pénible : `fastlane match` (repo certs chiffré), App Store Connect API key, App-Specific Password 2FA Apple ID, secrets GHA à câbler proprement. Comptez 1–3 jours pour avoir un pipeline stable la première fois.
- **−** Ruby + Gemfile à maintenir dans le repo (mises à jour fastlane régulières).
- **−** Plus de YAML / actions tierces à auditer.

### Option C — Hybride / différé

Faire du build local manuel (un seul Mac dev) jusqu'à v1, puis trancher. **Rejeté** : non scalable, pas reproductible, bloque les agents et la beta TestFlight pilotée par la CI.

## Décision

**Codemagic pour M1 et M2.**

Critères pondérés :

| Critère                                | Poids  | Codemagic            | GHA + fastlane                     |
| -------------------------------------- | ------ | -------------------- | ---------------------------------- |
| Vélocité time-to-first-green-build     | élevé  | ✅ ~1 h              | ❌ 1–3 jours                       |
| Coût aux volumes MVP (≤ 500 min/mois)  | élevé  | ✅ gratuit           | ⚠️ free tier serré (200 min macOS) |
| Coût en cas de débordement (×2 volume) | moyen  | ✅ ~20 $/mois        | ❌ ~40 $/mois                      |
| Simplicité signing iOS                 | élevé  | ✅ intégré           | ❌ `match` + secrets               |
| Cohérence avec backend/web (GHA)       | moyen  | ⚠️ plateforme à part | ✅ unifié                          |
| Lock-in                                | faible | ⚠️ YAML propriétaire | ✅ portable                        |
| Maintenance Ruby/fastlane              | faible | ✅ aucune            | ❌ Gemfile à suivre                |

Le facteur déterminant est la **vélocité** et le **coût en macOS minutes** au stade MVP. La cohérence GHA est un argument réel mais secondaire : les pipelines mobile et backend sont disjoints, donc avoir deux CI n'introduit pas de duplication ni de chaînage à maintenir.

## Conséquences

### Immédiates

- Création d'un compte Codemagic (org `piloo`), membres : dev principal + 1 agent service account.
- `codemagic.yaml` versionné à la **racine du repo** (Codemagic ne supporte pas un autre emplacement, cf. message UI "Save the codemagic.yaml file to the project root folder"). Les commandes Flutter utilisent `working_directory: apps/mobile`.
- Secrets stockés dans le vault Codemagic : App Store Connect API key, Play Console service account JSON, keystore Android (base64). **Aucun secret mobile n'entre dans GitHub Secrets.**
- GitHub Actions reste l'unique CI pour `apps/web`, `packages/*`, lint/typecheck monorepo.
- Documentation : un README court dans `apps/mobile/` expliquant comment relancer un build et où trouver les artefacts.

### Long terme / risques

- **Lock-in** modéré : le `codemagic.yaml` n'est pas trivialement portable, mais la logique (flutter build + fastlane-equivalent steps) est reproductible en GHA en quelques jours si besoin.
- **Coût** : si on dépasse régulièrement 500 min/mois (probable à partir de v1 si plusieurs agents poussent en parallèle), passer au plan payant Codemagic avant de reconsidérer.
- **Single point of failure** : une panne Codemagic bloque les releases mobile mais pas le backend/web. Avoir un runbook "build local + upload manuel TestFlight" en secours.

### Critères de réévaluation (réouvrir l'ADR si)

1. Volume mobile dépasse durablement 1 500 min/mois → comparer le coût Codemagic vs un Mac mini self-hosted runner GHA.
2. L'équipe grossit (≥ 3 devs mobile) et veut centraliser tous les checks GitHub-natifs.
3. Apple change ses APIs de signing au point que l'avantage Codemagic s'érode.
4. Besoin de pipelines mobile/backend chaînés (peu probable vu l'architecture).

## Notes

- L'ADR ne décrit **pas** le pipeline lui-même (étapes, triggers, branches). Voir le ticket d'implémentation `apps/mobile` pour le `codemagic.yaml`.
- Fastlane peut quand même être utilisé **à l'intérieur** des étapes Codemagic si on en a besoin pour des opérations fines (ex : `fastlane deliver` pour métadonnées App Store) — Codemagic ≠ exclusion de fastlane.
