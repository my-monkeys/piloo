# e2e — piloo (mobile) (Appium + WebdriverIO, iPhone réel)

Tests d'UI sur appareil iOS réel via Appium (driver XCUITest) et WebdriverIO.
Dossier autonome (hors workspace pnpm — seul `apps/web` est dans le workspace).

## Prérequis (déjà installés au niveau machine)

- Appium 3 + driver `xcuitest` (`appium driver list --installed`)
- Xcode + outils ligne de commande
- iPhone **Crookie** connecté **en USB**, déverrouillé, "approuvé" pour ce Mac
- Sur l'iPhone : **Mode développeur** activé (Réglages → Confidentialité et sécurité → Mode développeur) **et** **Enable UI Automation** ON (Réglages → Développeur)
- L'app piloo installée sur l'iPhone (sinon, fournis un build via `appium:app` dans `wdio.conf.js`)

> ⚠️ iPhone iOS 18+ : la connexion **USB est obligatoire** (le tunnel ne marche pas en Wi-Fi).

## Installation

```bash
cd apps/mobile/e2e
npm install
```

## Lancer les tests (3 terminaux)

```bash
# 1) Tunnel pour appareil réel iOS 18+ (laisser tourner, demande sudo)
npm run tunnel

# 2) Serveur Appium (laisser tourner)
npm run appium

# 3) Tests
npm test
```

Au **premier lancement**, Appium compile et signe le WebDriverAgent avec la team
`7U4ZZUR2PN`. Si l'iPhone affiche un profil non approuvé :
Réglages → Général → VPN & gestion d'appareils → approuver le profil développeur.

## Paramétrage

Tout est dans `wdio.conf.js`, surchargeable par variables d'env :

| Variable        | Défaut                                 | Rôle                                 |
| --------------- | -------------------------------------- | ------------------------------------ |
| `APP_BUNDLE_ID` | `fr.mymonkey.piloo`                    | app cible (attach)                   |
| `IOS_UDID`      | `00008150-001409EA0A78401C`            | UDID de l'iPhone                     |
| `XCODE_ORG_ID`  | `82CD4B7L8X`                           | Team de signature WDA (SCALAB GAMES) |
| `WDA_BUNDLE_ID` | `com.scalabgames.WebDriverAgentRunner` | bundle id du WDA                     |

## Mise en place faite une fois (pour mémoire)

Le WebDriverAgent a été pré-buildé/signé une fois pour créer le profil de provisioning
(sinon Appium échoue avec `xcodebuild code 65 / No profiles`). À refaire seulement si
la signature casse :

```bash
cd ~/.appium/node_modules/appium-xcuitest-driver/node_modules/appium-webdriveragent
xcodebuild build-for-testing -project WebDriverAgent.xcodeproj -scheme WebDriverAgentRunner \
  -destination 'id=00008150-001409EA0A78401C' -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=82CD4B7L8X \
  PRODUCT_BUNDLE_IDENTIFIER=com.scalabgames.WebDriverAgentRunner IPHONEOS_DEPLOYMENT_TARGET=27.0
```

Pour installer un build au lieu de t'attacher à l'app installée : commente
`appium:bundleId` et renseigne `appium:app` (chemin .ipa/.app) dans `wdio.conf.js`.
