# Spécifications fonctionnelles — Piloo

Ce document décompose les fonctionnalités du MVP en comportements précis, utilisables comme référence pour implémenter et tester.

> Voir `dossier-cadrage.md` pour la vision produit complète. Ce document est la traduction opérationnelle.

---

## 1. Comptes utilisateurs

### 1.1 Types de comptes

- **Particulier** : gère sa propre officine et éventuellement celles de proches.
- **Pro de santé** : gère plusieurs officines (patients). Rôle unifié couvrant aide-soignant, auxiliaire de vie, IDEL, SSIAD.

Le type de compte est choisi à l'inscription et peut être modifié depuis les paramètres.

### 1.2 Champs de compte

- Email (unique, utilisé pour l'auth)
- Mot de passe (hash bcrypt/argon2)
- Nom, prénom
- Type de compte (`particulier` ou `pro`)
- Numéro de téléphone (optionnel, requis si SMS activés)
- Date de création, dernière connexion
- Langue préférée (FR au MVP)
- Préférences de notification (push/email/SMS, activables par canal)

### 1.3 Authentification

- Inscription : email + mot de passe + type de compte.
- Vérification d'email obligatoire avant première connexion.
- Connexion : email + mot de passe.
- Mot de passe oublié : lien magique envoyé par email, expiration 1h.
- 2FA : optionnelle, recommandée pour les comptes pro (TOTP).
- Déconnexion : supprime la session (web) ou invalide le token (mobile).
- Suppression de compte : disponible depuis les paramètres, délai de grâce 7 jours avant effacement réel.

---

## 2. Officines

### 2.1 Définition

Une **officine** est un contenant logique de boîtes de médicaments. Une officine appartient à un propriétaire (unique) et peut être partagée avec d'autres utilisateurs.

Types d'officine :
- `perso` : l'officine personnelle d'un particulier.
- `patient` : une fiche patient gérée par un pro.

### 2.2 Création

- Un compte particulier a **une officine `perso` créée automatiquement** à la première connexion.
- Il peut créer d'autres officines (ex : pour un parent).
- Un compte pro ne crée pas d'officine auto, il crée des fiches patients à la demande.

### 2.3 Champs

- Nom (ex : "Maison", "Papa", "Mme Dubois")
- Type (`perso` | `patient`)
- Propriétaire (user_id)
- Date de naissance du titulaire (optionnel, utile pour posologie adaptée)
- Notes libres (allergies, précautions, contact médecin traitant)
- Date de création

### 2.4 Actions disponibles

- Créer / renommer / supprimer une officine (le propriétaire uniquement).
- Inviter un autre utilisateur en lui attribuant un rôle.
- Révoquer un partage.
- Quitter une officine partagée (pour les non-propriétaires).

---

## 3. Partages et droits

### 3.1 Rôles

| Rôle | Consulter | Ajouter/modifier boîtes | Gérer ordonnances | Marquer prises | Signaler manque | Gérer partages |
|---|---|---|---|---|---|---|
| **Propriétaire** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Éditeur** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Lecteur** | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |

Le rôle `Lecteur` peut **signaler un manque** parce que c'est un cas d'usage explicite (patient âgé qui n'a plus de médicament, avertit sa famille).

### 3.2 Invitation

- Le propriétaire génère un **lien d'invitation** signé (JWT court) avec :
  - ID officine
  - Rôle attribué
  - Expiration (72h par défaut, configurable)
- Le lien est envoyé par email (via Brevo) ou partagé manuellement.
- L'utilisateur qui clique doit être connecté (ou s'inscrire) pour accepter.
- Une fois accepté, le partage est créé dans `partages`.

### 3.3 Règles

- Un utilisateur peut être dans **N officines** avec des rôles différents.
- Un pro peut gérer N officines type `patient`.
- Un particulier peut aussi être invité sur une officine `patient` (ex : la fille de Raymond suivi par une IDEL).
- La révocation d'un partage est immédiate : le prochain appel API par cet utilisateur retourne 403.

---

## 4. Scan et gestion des boîtes

### 4.1 Scan d'un DataMatrix

**Workflow**

1. L'utilisateur ouvre l'écran scan.
2. La caméra s'active, `mobile_scanner` détecte un DataMatrix.
3. Le contenu est décodé et parsé en champs GS1 :
   - `AI 01` : GTIN → on en extrait le CIP13 (13 derniers chiffres)
   - `AI 17` : date de péremption (format YYMMDD)
   - `AI 10` : numéro de lot
   - `AI 21` : numéro de série
4. Le CIP13 est résolu via la base BDPM locale (SQLite) → nom du médicament, DCI, dosage, forme.
5. **Recherche du triplet `(officine_id, lot, numero_serie)`** dans la DB locale :
   - **Si absent** → flux d'ajout (section 4.2).
   - **Si présent** → popup actions rapides (section 4.3).

### 4.2 Flux d'ajout

Écran "Nouvelle boîte" avec :
- Aperçu du médicament reconnu (nom, dosage, forme, image si disponible)
- Date de péremption pré-remplie depuis le DataMatrix, modifiable
- Numéro de lot pré-rempli
- Numéro de série pré-rempli (masqué par défaut, accessible en "Détails")
- Choix de l'officine cible (dropdown si plusieurs)
- Nombre d'unités initial (pré-rempli selon BDPM si connu, sinon "Plein")
- Champ notes (optionnel)
- Bouton "Ajouter"

**Cas d'erreur**
- DataMatrix non pharma (ex : code produit random) → message "Ce code n'est pas un médicament reconnu".
- CIP13 absent de la BDPM locale → fallback saisie manuelle avec alerte "Médicament non trouvé dans la base, vérifiez les infos".
- Pas de numéro de série (vieilles boîtes pré-2019) → identification fallback par (CIP13 + lot), avertir l'utilisateur que deux boîtes identiques seront indistinguables.

### 4.3 Popup actions rapides (re-scan)

Déclenchée quand une boîte déjà connue est scannée.

**Header**
- Nom du médicament
- Dosage + forme
- "Déjà dans votre officine [Nom]"

**Actions disponibles** (ordre d'affichage)

1. **Marquer comme vide** → `statut = 'vide'`, retirée du stock actif, tracée dans l'historique. Demande confirmation.
2. **Ajuster le stock — rapide** → boutons `Plein` / `3/4` / `Moitié` / `1/4` / `Presque vide`. Un tap = mise à jour immédiate.
3. **Ajuster le stock — précis** → champ numérique, unité pré-remplie (ex : "12 comprimés"). Validation.
4. **Infos médicament** → ouvre la fiche info (section 4.4).
5. **Marquer comme périmée** → `statut = 'perimee'`, retirée du stock. Demande confirmation.
6. **Signaler un manque** → disponible pour tous les rôles. Crée une alerte visible par les autres partagés avec un rôle Éditeur ou Propriétaire.

### 4.4 Fiche info médicament

Accessible depuis la popup ou depuis une boîte dans l'inventaire.

**Contenu**
- Nom commercial + dosage + forme
- Principe actif (DCI) — cliquable : "Voir tous mes médicaments avec ce principe actif"
- Laboratoire
- Taux de remboursement
- **Résumé IA** (2-3 lignes) : à quoi sert le médicament en langage simple, précautions courantes. **Pré-généré serveur, stocké localement.**
- Bouton "Voir la notice officielle" → ouvre le PDF BDPM en navigateur.

**Avertissement en bas de fiche** : *"Informations à titre indicatif. Pour toute question, consultez votre médecin ou pharmacien."*

### 4.5 Inventaire

**Vue "Mes boîtes"**

Filtres :
- Par officine (si plusieurs)
- Par statut (actif / vide / périmé)
- Par date de péremption (tri croissant par défaut)

Regroupement :
- **Par défaut** : par médicament (toutes les boîtes du même CIP13 regroupées). Affichage : "Doliprane 1000mg — 3 boîtes"
- **Toggle "Par molécule (DCI)"** : regroupement par principe actif. Affichage : "Paracétamol — 5 boîtes (Doliprane × 3, Dafalgan × 2)"
- **Toggle "Toutes les boîtes"** : liste plate.

**Action sur groupe** : tap sur un groupe déplie la liste des boîtes individuelles (avec lot, péremption, niveau stock).

---

## 5. Ordonnances et timeline de prises

### 5.1 Saisie d'ordonnance

**Saisie manuelle**
1. L'utilisateur tape sur "Nouvelle ordonnance".
2. Il remplit :
   - Date de l'ordonnance
   - Prescripteur (texte libre : nom + spécialité)
   - Liste de prescriptions : pour chaque médicament, il scanne une boîte existante OU cherche par nom dans la BDPM.
3. Pour chaque prescription :
   - Médicament (CIP13 ou CIS)
   - Posologie structurée : nombre d'unités × fréquence (ex : `1 cp × 3/j`)
   - Moments de prise : matin / midi / soir / coucher (cochables) OU horaires précis
   - Avec/sans repas
   - Durée (en jours, ou "à vie")
   - Indication (optionnelle)
   - Notes (optionnelles)

**Saisie OCR (v2, prévue dans le MVP si le temps le permet)**
1. L'utilisateur tape sur "Scanner une ordonnance" → prend une photo.
2. L'image est envoyée à l'API serveur.
3. Le serveur l'envoie à un LLM vision (Claude, Mistral, ou Gemini) avec un prompt structuré.
4. Le JSON retourné est pré-rempli dans le formulaire de saisie.
5. **L'utilisateur doit valider** chaque ligne avant création — l'OCR aide, ne décide pas.

### 5.2 Génération de prises planifiées

À la création d'une ordonnance, le système génère les `prises_planifiees` :
- Si durée en jours : N occurrences par jour × durée.
- Si "à vie" : génération glissante (30 jours d'avance, régénéré en tâche de fond).
- Horaires par défaut selon les moments : matin = 8h, midi = 12h, soir = 19h, coucher = 22h (configurables dans les paramètres utilisateur).

### 5.3 Timeline de prises

**Écran principal mobile : "Aujourd'hui"**

Liste chronologique des prises du jour, groupées par moment :
- Matin (prises avant midi)
- Midi (prises de 12h à 16h)
- Soir (prises de 16h à 21h)
- Coucher (prises après 21h)

Pour chaque prise : nom médicament, dosage, nombre d'unités, statut, horaire prévu.

**Statuts possibles**
- `prevue` : à venir
- `prise` : validée par l'utilisateur
- `sautee` : marquée comme non prise intentionnellement
- `oubliee` : non validée 1h après l'horaire prévu, devient "oubliée" automatiquement

**Actions**
- Tap sur une prise → modale avec "Prise", "Sautée", "Reporter +30 min".
- Tap long → édition (changer l'horaire pour cette occurrence uniquement).

### 5.4 Notifications

**Push (FCM)**
- Envoyée 5 min avant l'horaire prévu (configurable).
- Action rapide dans la notif : "Pris" / "Sauter" / "Rappel dans 15 min".
- Sans action, nouvelle notif 30 min après (relance), puis le statut devient `oubliee` à +1h.

**Email**
- Envoyé uniquement si `oubliee` ET si le partage comporte un rôle avec notification configurée.
- Résumé quotidien optionnel (soir) pour un pro avec plusieurs patients.

**SMS (coûteux, usage limité)**
- Uniquement pour les alertes critiques : prise oubliée (personne âgée sans smartphone), stock épuisé signalé.
- Configurable et limité par utilisateur/jour.

---

## 6. Alertes

### 6.1 Types d'alertes

| Type | Déclenchement | Notifié à |
|---|---|---|
| `peremption_30j` | Boîte périme dans 30 jours | Propriétaire + Éditeurs |
| `peremption_7j` | Boîte périme dans 7 jours | Propriétaire + Éditeurs (push + email) |
| `stock_bas` | Stock estimé < 7 jours de traitement | Propriétaire + Éditeurs |
| `prise_oubliee` | Prise non validée à +1h | Propriétaire si activé, Éditeurs liés au patient |
| `manque_signale` | Un utilisateur a signalé un manque | Propriétaire + Éditeurs |

### 6.2 Calcul du stock estimé (alerte "stock bas")

Pour chaque médicament d'une officine :
- Somme des unités restantes estimées dans toutes les boîtes actives.
- Consommation quotidienne estimée depuis les prescriptions actives.
- Jours de stock = stock total / consommation.
- Alerte si < 7 jours.

Cette estimation est **indicative**. L'utilisateur peut corriger le stock via la popup actions rapides.

---

## 7. Synchronisation offline

### 7.1 Comportement côté mobile

- Toute action utilisateur est enregistrée **localement dans SQLite (Drift)** immédiatement.
- En parallèle, l'action est ajoutée à la table `pending_operations` avec `statut = 'pending'`.
- Quand le réseau est détecté (via `connectivity_plus`), un worker Dart envoie les opérations en batch à `/sync/push`.
- Les ACK serveur marquent les opérations `synced`.
- Un pull `/sync/pull?since=timestamp` est lancé à intervalle régulier pour récupérer les modifs des autres clients.

### 7.2 Conflits

- **Stratégie MVP** : last-write-wins sur le timestamp serveur.
- **Cas particulier** : pas de suppression réelle (toujours soft-delete via `deleted_at`).
- **Cas limite documenté** : 2 pros éditent la même boîte offline sur 2h, le plus récent gagne. Acceptable en V1.

### 7.3 Comportement offline côté UX

- Un badge "Synchronisation en attente" visible tant que `pending_operations` n'est pas vide.
- Les actions offline sont immédiatement visibles dans l'UI (optimistic update).
- En cas d'échec de sync après 3 tentatives, l'utilisateur est notifié et peut voir la liste des opérations en échec.

---

## 8. Spécifications non-fonctionnelles

### 8.1 Performance

- Temps de scan → reconnaissance BDPM → affichage : **< 1 seconde** sur un smartphone moyen.
- Premier affichage de la timeline "Aujourd'hui" : **< 500ms** en offline.
- Sync push : batch de 100 opérations max par appel, retry exponentiel.

### 8.2 Accessibilité

- Contrastes WCAG AA minimum.
- Support du text-scaling iOS/Android jusqu'à 200%.
- Labels ARIA sur tous les boutons icône côté web.
- Navigation au clavier complète côté web.
- Support VoiceOver / TalkBack côté mobile.

### 8.3 Confidentialité

- Les résumés IA sont pré-générés côté serveur et embarqués dans l'app mobile (pas d'appel IA à chaque scan).
- Aucun appel analytics tiers sur les écrans contenant des données médicales.
- Les logs serveur ne contiennent jamais de noms de médicaments, CIP, ou noms de patients en clair.

### 8.4 Compatibilité

- **Mobile** : iOS 14+ / Android 7+ (à confirmer selon les exigences des libs).
- **Web** : navigateurs modernes (Chrome/Edge/Firefox/Safari dernières 2 versions).
- **Offline** : toutes les features de consultation et la plupart des features d'édition doivent fonctionner.

---

## 9. Out of scope MVP

Les features suivantes sont **explicitement exclues** du MVP pour tenir le délai :

- OCR ordonnance (repoussé en v2)
- Alertes avancées (interactions médicamenteuses, etc.) — interdites par positionnement réglementaire
- Dashboard pro avec indicateurs (tournée du jour, taux d'observance…)
- Export PDF pour médecin
- Intégration Mon espace santé / DMP
- Application watchOS / Wear OS
- Multi-langue (FR only au MVP)
- Thèmes (light/dark/auto : à voir selon temps restant en M3)
- Analytics même anonymisés (décision à repousser)
