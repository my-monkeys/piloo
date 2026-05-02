# Roadmap — Piloo

Périmètre MVP : 3 mois en side-project. La stratégie est de **resserrer radicalement le scope** pour livrer quelque chose d'utilisable plutôt que beaucoup d'à moitié fait.

> Les priorités retenues sont les 3 premières du classement utilisateur : Scan + inventaire, Timeline + notifications, Partage. Les autres (compte pro complet, OCR, alertes avancées) sont en phase 2.

---

## Mois 1 — Fondations techniques

**Objectif** : une app mobile qui scanne une boîte et l'ajoute à une officine locale, avec sync basique vers un backend. Pas de polish, pas de features complètes. On prouve que la chaîne technique tient.

### Semaine 1-2 : Setup infra et POC critiques

- [ ] Setup monorepo Turborepo : `apps/web`, `packages/db-schema`, `packages/api-contract`.
- [ ] Initialisation app Flutter dans `apps/mobile`.
- [ ] Setup PostgreSQL local + cloud (Neon ou Railway).
- [ ] Config Drizzle : schéma initial (users, officines, boites, medicaments_bdpm).
- [ ] Première route Next.js API de test + validation Zod + pipeline `zod-to-openapi`.
- [ ] **POC critique 1** : génération client Dart depuis OpenAPI. Vérifier que le workflow tient.
- [ ] **POC critique 2** : scan d'un DataMatrix avec `mobile_scanner` sur 10 boîtes réelles. Vérifier le parsing GS1.
- [ ] Import BDPM : script côté serveur qui télécharge les TSV et peuple `medicaments_bdpm`.

### Semaine 3 : Auth + BDPM mobile

- [ ] Auth : inscription, login, vérification email (via Better Auth ou Clerk).
- [ ] Endpoint `/api/v1/auth/me` + middleware d'auth.
- [ ] Génération d'un fichier SQLite BDPM pour mobile (script côté serveur).
- [ ] Téléchargement + chargement du SQLite dans l'app Flutter (Drift).
- [ ] Résolution CIP13 → infos médicament, testée sur les 10 boîtes scannées.

### Semaine 4 : Sync + premier CRUD boîtes

- [ ] Table `pending_operations` côté Flutter (Drift).
- [ ] Worker Dart de sync (connectivity_plus + retry).
- [ ] Endpoints `/api/v1/sync/push` et `/sync/pull`.
- [ ] CRUD boîtes : création en local, sync serveur, récupération pull.
- [ ] Premier test end-to-end : scan une boîte offline → reconnecter réseau → la boîte apparaît côté serveur.

**Livrable fin M1** : on peut scanner une boîte, elle est enregistrée localement, elle se synchronise quand on a du réseau. Pas d'UI polie, mais ça marche.

---

## Mois 2 — Features cœur particulier

**Objectif** : l'app devient utile pour un particulier. Inventaire complet, ordonnances, rappels.

### Semaine 5 : UI inventaire + regroupement molécule

- [ ] Écran "Officine" (inventaire) mobile.
- [ ] Regroupement par médicament / par molécule (DCI).
- [ ] Barre de recherche.
- [ ] Filtres par statut.
- [ ] Écran détail boîte.

### Semaine 6 : Popup actions rapides + fiche info

- [ ] Détection "boîte déjà connue" au scan.
- [ ] Popup actions rapides (marquer vide, ajuster stock, infos médicament).
- [ ] Pré-génération des résumés IA pour top 500 médicaments BDPM (avec Claude Haiku). Stockage en DB.
- [ ] Fiche info médicament avec résumé IA.

### Semaine 7 : Ordonnances + prises planifiées

- [ ] Modèle de données prescriptions + prises_planifiees.
- [ ] Écran création ordonnance (saisie manuelle, posologie structurée).
- [ ] Génération des prises planifiées.
- [ ] Écran "Aujourd'hui" avec timeline de prises.
- [ ] Validation d'une prise (marquer prise / sautée).

### Semaine 8 : Notifications + polish

- [ ] Firebase Cloud Messaging config iOS/Android.
- [ ] Backend : scheduling de notifs via cron ou queue.
- [ ] Enregistrement device tokens + préférences.
- [ ] Notifications de rappel + actions rapides.
- [ ] Gestion des prises oubliées (job +1h).
- [ ] Polish UX : empty states, loading states, erreurs de scan.
- [ ] Déploiement web sur Vercel (pages landing + login + liste officines minimaliste).
- [ ] Build TestFlight iOS + APK interne Android.

**Livrable fin M2** : un particulier peut utiliser l'app pour gérer son officine familiale. Le web est minimal mais existant.

---

## Mois 3 — Partage et tests terrain

**Objectif** : mise en place du partage patient↔pro, durcissement de la sync, tests utilisateurs réels.

### Semaine 9 : Partages et rôles

- [ ] Modèle partages + endpoints.
- [ ] Écran "Mes officines" (liste avec bascule rapide).
- [ ] Écran "Gérer les partages" (owner invite, retire, change rôle).
- [ ] Token d'invitation signé + lien d'invitation.
- [ ] Écran "Accepter une invitation".

### Semaine 10 : Usage multi-officines (vue pro léger)

- [ ] Bascule rapide entre officines pour un pro avec plusieurs patients.
- [ ] Signalement de manque (tous rôles) + notification aux Éditeurs/Propriétaires.
- [ ] Badges alertes dans la tab bar.
- [ ] Écran Alertes (liste, marquer lu).

### Semaine 11 : Durcissement et préparation beta

- [ ] Durcissement de la sync : retries exponentiels, gestion des conflits, logs structurés.
- [ ] Tests unitaires sur la logique métier critique (sync, parsing GS1, BDPM matching).
- [ ] Revue de sécurité : vérifier que les permissions fonctionnent sur tous les endpoints.
- [ ] Rédaction CGU + politique de confidentialité (draft, à valider par un juriste avant v1 prod).
- [ ] Onboarding utilisateur + mentions "carnet de suivi" bien placées.

### Semaine 12 : Beta fermée

- [ ] Recrutement : 3-5 familles (proches, réseau) + 1-2 IDEL/aide-soignants.
- [ ] Mise à disposition via TestFlight + Play Console internal.
- [ ] Recueil de feedback (questionnaire + interviews).
- [ ] Bugfix critique.
- [ ] Débrief et décisions pour la phase 2.

**Livrable fin M3** : MVP fonctionnel testé par de vrais utilisateurs. Documentation des apprentissages pour la phase suivante.

---

## Phase 2 (M4-M6) — Non prévu au MVP

Cadré dans le dossier mais reporté :

- Compte pro complet avec dashboard tournée.
- OCR d'ordonnance (Claude Vision ou Mistral OCR).
- Canaux email + SMS de notification.
- Alertes péremption avancées + estimation rupture.
- Export PDF pour médecin traitant.
- Onboarding dédié "mode aidant".

---

## Phase 3+ — Vision long terme

- **Migration HDS** (Hébergement de Données de Santé certifié). Obligatoire pour vraie prod.
- Intégration Mon espace santé / DMP (si API ouverte aux éditeurs tiers).
- Application watchOS / Wear OS pour validation prise au poignet.
- Intégration pharmacie partenaire (renouvellement en 1 clic).
- Internationalisation (d'abord Belgique / Suisse francophone qui ont BDPM équivalentes).
- Mode hors ligne renforcé pour zones rurales.

---

## Critères d'avancement

Pour chaque semaine, on vérifie :
- [ ] Les tâches prévues sont faites ou arbitrage documenté.
- [ ] Le code est sur `main` (ou branche fusionnée), pas juste en local.
- [ ] Les tests critiques passent.
- [ ] La démo de fin de semaine est jouable (même sur écran seul).

---

## Règle d'arbitrage

**À chaque fois qu'on dérape sur le planning** (au moins à la fin de chaque sprint de 2 semaines) :
1. On ne ralentit pas sur les fondations (sync, BDPM, scan).
2. On coupe sur le polish avant de couper sur une feature core.
3. Si on doit couper une feature P0, on documente pourquoi et on communique.
4. On ne sacrifie pas la sécurité/auth/RGPD, même sous pression.
