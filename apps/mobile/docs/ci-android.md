# CI Android — pipeline build & upload Play Console

Pipeline défini dans `apps/mobile/codemagic.yaml`, workflow `android-release`.

## Déclencheur

Tag git matchant `v*` (ex. `v0.1.0`, `v1.2.3-beta.1`). Aucun build Android signé n'est produit sur PR ou push branche : la CI PR (`mobile-ci.yml`, autre ticket) reste limitée à `flutter analyze` + `flutter test`.

## Sortie

- AAB signé uploadé automatiquement sur la **piste interne** ("internal" track) de la Play Console, en mode draft (à promouvoir manuellement après QA interne).
- APK signé téléchargeable depuis l'onglet *Artifacts* du build Codemagic — c'est cet APK qui sert pour la distribution interne hors Play (sideload équipe, beta-testeurs sans compte Google Play).
- Mapping ProGuard / R8 archivé dans les artefacts pour pouvoir déobfusquer les crash reports.

## Versioning

Le tag git est la source de vérité.

`v1.2.3` → `pubspec.yaml` réécrit en `version: 1.2.3+<count>` où `<count>` = `git rev-list --count HEAD`. Le build number est strictement croissant, exigence Play Console.

## Secrets requis

Stockés dans le **vault Codemagic** (pas dans GitHub Secrets, cf. `docs/adr/0002-flutter-ci.md`). Deux groupes d'environnement :

### Groupe `android_keystore`

| Variable | Description |
|---|---|
| `KEYSTORE_FILE` | Keystore JKS encodé base64 (`base64 -i piloo-release.jks`). |
| `KEYSTORE_PASSWORD` | Mot de passe du keystore. |
| `KEY_ALIAS` | Alias de la clé (ex. `piloo-release`). |
| `KEY_PASSWORD` | Mot de passe de la clé (souvent identique au keystore). |

Génération initiale (à faire une seule fois, sauvegarder le `.jks` hors-repo dans le coffre-fort partagé) :

```bash
keytool -genkey -v \
  -keystore piloo-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias piloo-release
```

### Groupe `google_play`

| Variable | Description |
|---|---|
| `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | JSON complet du service account GCP autorisé sur la Play Console. |

Création du service account :

1. Console GCP → IAM → service account dédié `piloo-play-publisher`.
2. Générer une clé JSON, copier le contenu intégral dans le secret Codemagic.
3. Play Console → *Setup* → *API access* → inviter le service account, donner les droits "Release manager" sur l'app `fr.mymonkey.piloo`.
4. Premier upload manuel obligatoire (Google n'accepte pas un upload API sur une app sans build initial).

## Configuration côté Gradle

Le fichier `apps/mobile/android/key.properties` est généré à chaque build (étape `Write key.properties`). Le `apps/mobile/android/app/build.gradle` doit lire ce fichier pour la `signingConfigs.release` ; voir le template Flutter standard. Le fichier `key.properties` et `keystore.jks` sont **gitignorés** (cf. `.gitignore` racine + section ci-dessous).

## Gitignore

À ajouter dans `apps/mobile/android/.gitignore` quand le projet Flutter sera scaffoldé :

```
key.properties
app/keystore.jks
*.jks
```

## Validation locale du YAML

```bash
bash scripts/check-codemagic-yaml.sh
```

Vérifie que le YAML parse et que les clés critiques (trigger tag `v*`, signing keystore, publishing Play track `internal`) sont bien présentes. Cette commande tourne sans dépendance externe (Python 3 stdlib).

## Coût estimé

Build M1 ~10 min × 1–2 releases/semaine ≈ 80 min/mois → confortablement dans le free tier 500 min/mois (cf. ADR 0002).

## Runbook panne

Si Codemagic est down et qu'il faut publier en urgence :

```bash
cd apps/mobile
flutter build appbundle --release   # nécessite key.properties + keystore.jks locaux
# Upload manuel via Play Console UI (Internal testing → Create release).
```

Le keystore et le service account JSON doivent être disponibles dans le coffre-fort partagé pour ce scénario.
