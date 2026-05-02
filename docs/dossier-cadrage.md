# Dossier de cadrage — Piloo

> *Projet Piloo — carnet numérique de médicaments pour la maison*
> Version 0.3 · Avril 2026

**Décisions récentes** (non encore intégrées au corps du document, cf. `ui-ux-guidelines.md` pour détails) :
- Nom du produit : **Piloo**
- Direction visuelle : **A+C** (beige chaleureux + précision nordique + accent terracotta)
- Mode : light only au MVP
- Onboarding : obligatoire
- Tab bar : 3 onglets (Aujourd'hui / Officine / Plus) + scan en FAB
- Icônes : Phosphor
- Typo : Fraunces (titres) + Manrope (corps)

---

## 1. Vision & pitch

### 1.1 Pitch en une phrase

Une application web et mobile qui permet à chacun de gérer son armoire à pharmacie comme une vraie officine : scanner ses boîtes, connaître ses stocks, suivre ses prises, et — pour les professionnels de santé à domicile — maintenir à jour l'inventaire de leurs patients avec un partage sécurisé et des alertes intelligentes.

### 1.2 Problèmes identifiés

**Côté particulier**
- On ne sait jamais vraiment ce qu'on a chez soi : on rachète du Doliprane alors qu'on en a déjà trois boîtes.
- Les dates de péremption sont ignorées : on jette, ou pire, on prend des médicaments périmés.
- La gestion d'une ordonnance avec plusieurs médicaments à prises multiples est source d'oublis.
- Pour les personnes âgées, la charge mentale est lourde et les erreurs fréquentes.

**Côté professionnel (aide-soignant, IDEL, SSIAD)**
- Le suivi des médicaments des patients à domicile se fait souvent sur papier ou dans un fichier Excel partagé.
- Difficile d'anticiper un renouvellement d'ordonnance ou une rupture de stock chez un patient.
- Pas de canal structuré entre le pro et le patient (ou son aidant familial) pour signaler un manque.
- Risque d'oubli de prise non détecté entre deux visites.

### 1.3 Proposition de valeur

| Utilisateur | Ce que l'app apporte |
|---|---|
| Particulier | Scan rapide, inventaire toujours à jour, rappels de prise, alertes péremption |
| Aidant familial | Vue partagée de l'officine d'un proche, possibilité d'alerter le pro |
| Pro de santé | Multi-patients, timeline des prises, alertes croisées stock + non-prise, sync offline sur le terrain |

### 1.4 Analyse concurrentielle et positionnement

Le marché se scinde en deux mondes distincts qui ne se parlent pas, ce qui ouvre un espace de positionnement.

**Grand public — apps de rappel et suivi médicaments**

| Acteur | Scan CIP/DataMatrix | Inventaire stock | Rappels | Partage aidant | Regroupement molécule | Tarif |
|---|---|---|---|---|---|---|
| **Medissimo / Kimed** 🇫🇷 | ✅ | ✅ | ✅ | ✅ | ❌ | Gratuit (couplé au pilulier physique Medipac, financé pharma) |
| **MyTherapy** 🇩🇪 | ❌ | ✅ | ✅ | ✅ | ❌ | Gratuit (data sharing publicitaire) |
| **Medisafe** 🇺🇸 | ❌ | ✅ | ✅ | ✅ | ❌ | ~4,99$/mois ou 39,99$/an (passé payant en 2026) |
| **TOM Medications** 🇨🇭 | ❌ | ✅ | ✅ | ❌ | ❌ | Gratuit |
| **Preskri / Pharmabox** 🇫🇷 | ❌ | ✅ | ✅ (+ appel vocal) | ⚠️ En dev | ❌ | Gratuit |
| **Goodmed** 🇫🇷 | ✅ (QR) | ❌ | ❌ | ❌ | ❌ | Gratuit (info uniquement) |

**Pro — logiciels SSIAD / services à domicile**

| Acteur | Périmètre | Certifications | Tarif |
|---|---|---|---|
| **Ximi SSIAD** | Suite ERP complète SSIAD/SAAD | HDS + ISO 27001/27018/20000 + Ségur | Sur devis, plusieurs k€/an |
| **Domilink SSIAD** (DICSIT) | 450+ SSIAD, dossier soins + mobile offline | Ségur, DMP, MS Santé | Sur devis |
| **Cedi'Acte** (CERIG) | 300+ ESMS, suite complète | HDS | Sur devis |
| **iMedicale / AtHome SSIAD** | SSIAD avec bilans et suivi | HDS | Sur devis |
| **BL.domicile** (Berger-Levrault) | Suite ESMS multi-modules | HDS, Ségur | Licence entreprise |

**Constats clés**
- **Medissimo** est le concurrent français le plus direct côté particulier, mais son écosystème est **couplé au pilulier physique Medipac** et au réseau de pharmacies partenaires. Sans Medipac, l'expérience est dégradée.
- **Medisafe est passé payant en janvier 2026** → fenêtre d'opportunité concrète pour capter des utilisateurs en recherche d'alternative.
- **Aucun concurrent ne propose le regroupement par molécule (DCI)** — alors que c'est l'usage naturel quand on ouvre son armoire à pharmacie ("combien de paracétamol j'ai, toutes marques confondues ?").
- **Aucun ne propose un vrai pont bidirectionnel patient↔pro sur l'officine** avec rôles granulaires et signalement de manque.
- Côté pro, les **suites SSIAD** sont des ERP lourds (planning, facturation, paie, RH) où le suivi médicament n'est qu'un module parmi 15. **Trou de marché** pour les IDEL libéraux et aides-soignants indépendants qui bricolent aujourd'hui avec Excel ou papier.

**Positionnement stratégique retenu**

> **« Le carnet numérique de médicaments pour la maison, avec un pont léger vers le pro qui passe vous voir. »**

Trois angles de différenciation :

1. **Focus radical sur l'officine domestique** — là où les concurrents sont piluliers-centrés (Medissimo), rappels-centrés (Medisafe/MyTherapy) ou ERP-centrés (SSIAD). On est mono-produit sur ce besoin précis.
2. **Regroupement par molécule + inventaire réel** — fonctionnalité absente partout, parle immédiatement à n'importe qui ouvrant son armoire à pharmacie.
3. **Pont léger pro↔patient** — pour IDEL libéraux et aidants familiaux, sans prétention d'ERP SSIAD. Cible les pros non rattachés à une structure lourde.

**Forces concurrentielles à défendre**
- Timing : vague d'utilisateurs cherchant une alternative à Medisafe devenu payant.
- Offline-first réel (scan + saisie + consultation sans réseau).
- Positionnement privacy-first possible si on évite le modèle data-sharing publicitaire de MyTherapy.

**Faiblesses à assumer**
- Pas de data source premium type ordonnance directe depuis pharmacie (contrairement à Medissimo).
- Pas de HDS au POC → ne peut pas viser le marché SSIAD structuré tant que la migration HDS n'est pas faite.
- Démarrage from scratch face à des concurrents avec années de polish UX et bases utilisateurs énormes.

### 1.5 Positionnement réglementaire — ce que l'app est et n'est pas

**L'app est** un carnet de suivi personnel numérique. Elle permet d'enregistrer une ordonnance **déjà délivrée** (prescrite par un médecin, dispensée par un pharmacien), de suivre son stock à la maison, et de s'organiser pour les prises. Même usage côté pro : l'aide-soignant ou l'IDEL s'en sert comme d'un cahier de liaison numérique, pas comme d'un outil d'acte médical.

**L'app n'est pas** :
- Un outil de validation clinique d'ordonnance.
- Un substitut à l'ordonnance officielle (seule l'ordonnance papier ou e-prescription fait foi).
- Un outil de prescription ou de modification de prescription.
- Un dispositif médical au sens du règlement européen MDR (on ne fait ni diagnostic, ni recommandation thérapeutique automatisée).
- Un canal d'alerte médicale officiel (pas de remplacement du 15/112, pas de communication patient-médecin réglementée).

**Conséquences concrètes**
- Mentions à afficher dans l'onboarding, les CGU, l'écran de saisie d'ordonnance, les alertes : *"Cet outil est un aide-mémoire personnel. Il ne remplace ni votre ordonnance, ni l'avis de votre médecin ou pharmacien."*
- Pas de marquage CE médical nécessaire (on reste hors champ MDR).
- Les alertes de "non-prise" envoyées à un aidant ou un pro sont des notifications entre proches, pas des alertes cliniques.
- L'utilisateur reste responsable de la justesse de ce qu'il saisit (l'OCR aide mais ne valide pas).

Ce positionnement doit être **assumé et visible**, pour éviter toute requalification juridique du produit.

### 1.5 Positionnement réglementaire — ce que l'app **n'est pas**

Point **fondamental** à clarifier dès le départ et à rappeler partout (CGU, onboarding, écrans clés) :

**L'application est un carnet numérique d'aide-mémoire personnel.** Elle permet d'enregistrer une ordonnance **déjà délivrée** par un professionnel de santé, de suivre le stock de médicaments au domicile, et de générer des rappels de prise.

**L'application n'est pas :**
- Un dispositif médical (DM) au sens du règlement européen MDR 2017/745 — elle ne fait aucune recommandation clinique, aucune aide à la décision thérapeutique, aucune alerte médicale.
- Un outil de validation ou de prescription — l'ordonnance officielle reste celle délivrée par le médecin, l'app n'en est qu'une retranscription à usage personnel.
- Un substitut à l'avis du médecin, du pharmacien ou de l'infirmier.
- Un outil opposable juridiquement — elle ne fait pas foi dans un contexte médico-légal.

**Conséquences pratiques :**
- Pas de marquage CE médical requis, pas de procédure ANSM.
- Le pro de santé (IDEL, aide-soignant) utilise l'app comme il utiliserait un cahier de liaison ou un tableur partagé, pas comme un acte médical.
- Les "alertes non-prise" sont des rappels entre proches/aidants, pas des alertes médicales.
- La responsabilité de la concordance entre la saisie dans l'app et l'ordonnance réelle incombe à l'utilisateur qui saisit.

Cette posture doit être explicite dans **les CGU, les mentions d'information au premier lancement, et les écrans de saisie d'ordonnance** (disclaimer visible).

---

## 2. Personas & cas d'usage

### 2.1 Personas

**Claire — 34 ans, parent de deux enfants**
Gère l'armoire à pharmacie familiale. Veut savoir en un coup d'œil ce qu'il reste de Doliprane enfant, ce qui est périmé, et ne plus avoir à chercher sur le paquet à quoi sert tel médicament. Utilisation principale : mobile, scan au retour de pharmacie.

**Raymond — 78 ans, retraité, suit 5 médicaments quotidiens**
Doit prendre des médicaments matin, midi et soir. Sa fille Claire lui a créé un compte. Elle gère à distance depuis son téléphone, lui reçoit des rappels sur son portable (SMS plutôt que push). Lecture seule sur son profil pour éviter qu'il supprime des lignes par erreur.

**Sarah — 42 ans, infirmière libérale**
Tourne chez 15 patients par jour. Besoin d'un accès rapide à chaque fiche patient, scan des nouvelles boîtes, mise à jour du stock. Travaille souvent sans réseau (campagne). Veut être alertée quand un patient signale un manque.

**Centre SSIAD Les Mimosas**
Plusieurs aides-soignants se partagent les tournées. Besoin d'une vue multi-patients, d'une main courante partagée entre collègues, d'une délégation d'accès côté famille.

### 2.2 Cas d'usage principaux

1. **Ajouter une boîte à mon officine** : ouvrir l'app, scanner le DataMatrix, confirmer, c'est ajouté avec date de péremption et lot.
2. **Savoir combien de Doliprane j'ai** : ouvrir la vue "molécule", paracétamol → 3 boîtes (2 non entamées, 1 à moitié).
3. **Retranscrire une ordonnance et programmer les prises** : à partir d'une ordonnance déjà délivrée par un médecin, saisir manuellement ou via OCR les prescriptions dans l'app, générer un planning matin/midi/soir pour la durée indiquée, recevoir une notif à chaque échéance. *L'ordonnance originale reste la référence officielle.*
4. **Valider une prise** : cliquer "pris" sur la notif ou dans l'app. Si non pris dans X minutes, escalade optionnelle.
5. **Partager mon officine à un pro** : générer un lien d'invitation, définir les droits (éditeur/lecteur), le pro accepte et voit la fiche.
6. **Pro : voir la tournée du jour** : liste des patients visités aujourd'hui, prises à valider, stocks à vérifier.
7. **Signaler un manque** : patient clique "plus de stock" sur un médicament, son aidant ou le pro qui le suit est notifié (rappel entre proches, pas alerte médicale).
8. **Alerte péremption** : l'app détecte qu'une boîte périme dans 30 jours et notifie le propriétaire.

---

## 3. Périmètre fonctionnel

### 3.1 Fonctionnalités par priorité (MVP → v2 → v3)

| # | Fonctionnalité | Priorité | Phase cible |
|---|---|---|---|
| 1 | Scan DataMatrix + inventaire officine particulier | P0 | MVP (M1-M3) |
| 2 | Résolution CIP via BDPM locale | P0 | MVP |
| 3 | Regroupement par molécule (DCI) | P0 | MVP |
| 4 | Timeline de prises + notifications push | P0 | MVP |
| 5 | Authentification + comptes particulier | P0 | MVP |
| 6 | Offline complet avec sync | P0 | MVP |
| 6b | Popup "actions rapides" au rescan d'une boîte connue | P0 | MVP |
| 7 | Partage officine avec 3 rôles (Propriétaire/Éditeur/Lecteur) | P1 | v2 (M4-M5) |
| 8 | Compte pro avec fiches patients multiples | P1 | v2 |
| 9 | Signalement de manque patient → pro | P1 | v2 |
| 10 | Notifications SMS + email (fiabilité) | P1 | v2 |
| 11 | OCR d'ordonnance (photo → prescription structurée) | P2 | v3 (M6+) |
| 12 | Alertes péremption avancées | P2 | v3 |
| 13 | Estimation date de rupture de stock | P2 | v3 |
| 14 | Dashboard pro (tournée du jour, indicateurs) | P2 | v3 |
| 15 | Historique & export PDF (pour médecin traitant) | P3 | v4 |

### 3.2 Détail des entités métier

**Officine** : contenant logique des médicaments d'un foyer ou d'un patient. Un utilisateur a au moins une officine. Un pro peut avoir N officines (une par patient).

**Médicament (catalogue)** : entrée de la BDPM, identifiée par code CIS (spécialité) et CIP (présentation). Immuable, synchronisée depuis la BDPM.

**Boîte** : instance physique. Appartient à une officine. Possède : un médicament de référence, un numéro de lot, une date de péremption, une date d'ajout, un nombre d'unités restantes (estimé).

**Molécule / DCI** : substance active. Un médicament a 1..N substances. Permet le regroupement "tous mes paracétamols".

**Ordonnance (retranscrite)** : **copie personnelle** d'une ordonnance papier ou numérique *déjà délivrée* par un médecin. Contient : prescripteur (texte libre), date, lignes de prescription. L'app ne fait que stocker cette retranscription — la valeur opposable reste sur l'ordonnance originale.

**Prescription (ligne)** : ligne d'une ordonnance retranscrite. Médicament + posologie (ex: 1 cp 3×/j) + durée + indication. Saisie par l'utilisateur (ou extraite via OCR puis validée par l'utilisateur).

**Prise planifiée** : occurrence générée à partir d'une prescription retranscrite. A un horaire, un statut (prévue/prise/sautée/oubliée). Sert de rappel personnel, pas d'acte de traçabilité médicale.

**Partage** : lien entre un utilisateur et une officine avec un rôle (Propriétaire / Éditeur / Lecteur).

**Alerte** : événement notifié (péremption, stock bas, prise non validée, signalement de manque).

### 3.3 Focus feature : popup "actions rapides" au rescan

**Principe** : quand un utilisateur scanne une boîte déjà présente dans son officine, l'app n'ajoute pas un doublon mais propose une popup d'actions contextuelles. C'est une interaction **pensée pour la vitesse** : au lieu de chercher la boîte dans l'inventaire pour la modifier, on la scanne à nouveau et on agit directement.

**Identification unique d'une boîte**

Une boîte est identifiée comme "déjà connue" via le couple **numéro de lot (GS1 AI 10) + numéro de série (GS1 AI 21)**. Le numéro de série est unique par boîte physique grâce à la sérialisation européenne imposée par la directive Medicrime (Falsified Medicines Directive 2011/62/UE). Deux boîtes du même médicament, même lot, auront deux n° de série différents — zéro ambiguïté.

**Actions proposées dans la popup**

| Action | Effet |
|---|---|
| Marquer comme vide | Retire la boîte de l'inventaire, garde trace dans l'historique |
| Ajuster le stock (rapide) | Boutons prédéfinis : Plein / 3/4 / Moitié / 1/4 / Presque vide |
| Ajuster le stock (précis) | Champ numérique pour saisir le nombre exact d'unités restantes |
| Infos rapides sur le médicament | Résumé IA court + infos BDPM + lien notice officielle |
| Marquer comme périmée | Retire du stock, trace spécifique dans l'historique |
| Signaler un manque (rôle Lecteur) | Notifie le propriétaire ou le pro lié que la boîte se vide |

**Composition de la fiche "Infos rapides"**

- **Résumé IA** (2-3 lignes) : à quoi sert le médicament en langage simple, principe actif, précautions courantes. Exemple : *"Paracétamol 1000mg. Antalgique et antipyrétique utilisé contre la douleur et la fièvre. Maximum 3g/jour chez l'adulte. À espacer de 6h entre deux prises."*
- **Infos structurées BDPM** : DCI, dosage, forme pharmaceutique, voie d'administration, laboratoire, taux de remboursement.
- **Lien vers la notice officielle** (PDF BDPM) pour l'utilisateur qui veut tout détail.

**Contrainte technique importante** : le résumé IA ne peut pas être généré à la volée (coût API, latence, incompatible offline). Il faut le **pré-générer** pour tous les médicaments BDPM via un job batch et le stocker dans la base embarquée. À refaire quand la BDPM s'enrichit de nouveaux médicaments (diff mensuel). Budget one-shot : ≈15 800 médicaments × ~200 tokens output ≈ quelques dizaines d'euros avec un modèle correct.

**Wireframe mental**

```
┌────────────────────────────────┐
│  📷 Scan détecté               │
│                                │
│  DOLIPRANE 1000mg              │
│  Boîte de 8 cp · Lot A2401     │
│  Déjà dans votre officine      │
│  ─────────────────────────     │
│                                │
│  [🗑  Marquer comme vide   ]   │
│  [📊 Ajuster le stock      ]   │
│  [ℹ️  Infos médicament     ]   │
│  [⚠️  Marquer comme périmée]   │
│                                │
│  [Annuler]                     │
└────────────────────────────────┘
```

---

## 4. Architecture technique

### 4.1 Stratégie : deux codebases distincts, contrat API partagé

Choix assumé : **pas de cross-plateforme web/mobile**. On aura deux applications séparées, chacune optimale sur sa cible, qui partagent uniquement le contrat API.

- **Mobile** : **Flutter** (Dart). Choisi pour sa stabilité, l'absence du churn Expo/React Native, un écosystème qui ne casse pas à chaque upgrade Node.js.
- **Web** : **Next.js 15** (TypeScript, App Router). Excellent SSR, déploiement simple, convient parfaitement à une app professionnelle côté pros de santé.
- **Backend** : routes API Next.js avec validation **Zod**, exposées en REST, contrat **OpenAPI** généré automatiquement.
- **Contrat partagé** : schéma OpenAPI → génération du client Dart (mobile) et du client TypeScript (web).

Le surcoût d'avoir deux codebases (double UI, double implémentation d'écrans) est compensé par la meilleure qualité native mobile et une stack web propre sans les contorsions React Native Web.

### 4.2 Architecture globale

```
┌─────────────────────┐         ┌─────────────────────┐
│  App mobile Flutter │         │  Next.js Web        │
│  - Dart / Widgets   │         │  - React (App Rtr)  │
│  - Riverpod (state) │         │  - Tailwind/shadcn  │
│  - Drift SQLite     │         │  - TanStack Query   │
│  - Sync custom      │◄───────►│                     │
└──────────┬──────────┘         └──────────┬──────────┘
           │                               │
           │  HTTP REST (OpenAPI contract) │
           └───────────────┬───────────────┘
                           ▼
          ┌────────────────────────────────┐
          │   Backend (Next.js API Routes) │
          │   - Validation Zod             │
          │   - Génération OpenAPI         │
          │   - Auth (Better Auth/Clerk)   │
          │   - Sync engine (custom)       │
          │   - Notifications (FCM/Brevo)  │
          └────────────────┬───────────────┘
                           ▼
          ┌────────────────────────────────┐
          │  PostgreSQL (Drizzle ORM)      │
          │  + Redis (queues notifs, v2)   │
          └────────────────────────────────┘
```

### 4.3 Stack mobile (Flutter)

| Couche | Techno | Justification |
|---|---|---|
| Framework | **Flutter 3.x** + **Dart** | Stabilité, pas de churn, écosystème mature |
| State mgmt | **Riverpod** | Standard moderne, typé, testable |
| Navigation | **go_router** | Officiel Flutter, URL-based, deep linking |
| Modèles immuables | **freezed** + **json_serializable** | Classes data + sérialisation |
| DB locale | **Drift** (SQLite) | ORM typé, migrations, top écosystème |
| Sync offline | **Custom** (append-only operations log) | Zéro dépendance tierce, maîtrise totale |
| HTTP | **Dio** + client généré depuis OpenAPI | Interceptors, retry, typage auto |
| Scan DataMatrix | **mobile_scanner** (MLKit) | Support GS1 DataMatrix natif |
| Parsing GS1 | Package communautaire ou custom | Décomposition AI(01/10/17/21) |
| Forms | **reactive_forms** ou **flutter_hooks** + **form_builder** | |
| Notifs push | **firebase_messaging** + **flutter_local_notifications** | FCM pour push, local pour rappels de prise |
| Tests | Dart unit tests + **integration_test** | Built-in Flutter |
| CI/CD | **Codemagic** ou GitHub Actions + fastlane | |

### 4.4 Stack web (Next.js)

| Couche | Techno | Justification |
|---|---|---|
| Framework | **Next.js 15** App Router + **TypeScript** | Server Components, SSR, routing moderne |
| Styling | **Tailwind CSS** + **shadcn/ui** | Rapide, composants de qualité, full customisation |
| Forms & validation | **React Hook Form** + **Zod** | Zod sert aussi côté backend |
| State serveur | **TanStack Query** | Cache, invalidation, retries |
| State client | **Zustand** | Léger, typé |
| ORM serveur | **Drizzle** | Typage TS natif, migrations SQL claires |
| Auth | **Better Auth** ou **Clerk** | Clerk si on veut aller très vite, Better Auth si on veut zéro vendor |
| Validation API | **Zod** → génération **OpenAPI** via `zod-to-openapi` | Contrat partagé avec Flutter |
| Tests | **Vitest** + **Playwright** | Unit + E2E |
| Déploiement | **Vercel** (POC) ou **Railway** | Vercel zero-config, Railway plus économique |

### 4.5 Stack backend partagée (dans Next.js)

- **Routes API** Next.js (App Router, route handlers) validées par Zod.
- **Génération OpenAPI** automatique depuis les schémas Zod → source de vérité du contrat.
- **Auth** : Better Auth ou Clerk. JWT pour le mobile, session cookie pour le web.
- **PostgreSQL** managé (Railway, Neon ou Supabase).
- **Sync engine** : endpoints dédiés `/sync/pull` (diff depuis timestamp) et `/sync/push` (batch d'opérations).
- **Notifications** : FCM (push mobile), Brevo (email + SMS).

**Note** : on garde la possibilité d'extraire le backend en service séparé (Fastify/NestJS) plus tard si les besoins de scale le justifient. Au MVP, tout dans Next.js = un seul deploy, un seul service.

### 4.6 Sync offline custom — pattern recommandé

Choix validé : pas de PowerSync/Electric, on code la sync nous-mêmes. Voici le pattern à implémenter :

**Côté client (Flutter)**
- Chaque modification locale (ajout boîte, marquage vide, validation prise…) est enregistrée à la fois dans la base Drift ET dans une table `pending_operations` (file d'attente).
- Chaque opération a : `id` (UUID client), `type`, `payload`, `timestamp_local`, `statut` (pending | syncing | synced | conflict).
- Au retour du réseau (détecté via `connectivity_plus`), un worker vide la file : il envoie les opérations au serveur, attend les ACK, marque `synced`.

**Côté serveur**
- Endpoint `POST /sync/push` reçoit un batch d'opérations client, les applique, retourne les ACK + éventuels conflits.
- Endpoint `GET /sync/pull?since=timestamp` renvoie les modifs serveur postérieures au timestamp client → pour la synchro entrante (ex : autre utilisateur a modifié l'officine partagée).

**Gestion des conflits**
- Stratégie MVP : **last-write-wins** sur le timestamp serveur. Simple, prédictible.
- Cas particulier : suppressions. On ne supprime jamais vraiment → on marque `deleted_at`. Le client applique les soft-deletes à la sync.
- Cas limite à documenter : deux pros éditent la même boîte offline pendant 2h, synchronisent dans des ordres différents → le plus récent gagne. Acceptable au MVP, à affiner avec CRDT plus tard si besoin.

**Charge estimée** : 3-5 jours en M1 pour un premier jet fonctionnel, 2-3 jours supplémentaires en M2 pour durcir (retries, reprise après crash, observabilité).

### 4.7 Contrat API via OpenAPI

**Workflow de génération**

```
┌──────────────────────┐
│ Schémas Zod          │  ← source de vérité (backend Next.js)
│ (validation des      │
│  route handlers)     │
└──────────┬───────────┘
           │
           ▼ zod-to-openapi
┌──────────────────────┐
│ openapi.yaml         │  ← artefact commité dans le repo
└──────────┬───────────┘
           │
           ├────► openapi-typescript    → types TS (web)
           │
           └────► openapi-generator     → client Dart + modèles (mobile)
                  (ou dart_openapi_client)
```

**Avantages**
- Un seul endroit où définir la forme des données (Zod côté serveur).
- Clients Dart et TS regénérés automatiquement à chaque changement d'API.
- Documentation API vivante (Swagger UI sur `/docs`).
- Zéro divergence possible entre backend et clients.

**Charge** : 1-2 jours en M1 pour la mise en place initiale (pipeline, premiers endpoints, script de regen). Puis coût marginal très faible.

### 4.8 Décodage du DataMatrix pharmaceutique

Les boîtes françaises portent un DataMatrix au format **GS1** contenant :
- AI (01) : code GTIN/CIP13 → identifie le médicament
- AI (17) : date de péremption (YYMMDD)
- AI (10) : numéro de lot
- AI (21) : numéro de série (unique par boîte, sérialisation FMD 2019+)

Côté Flutter : `mobile_scanner` détecte et décode le DataMatrix, puis parsing des AI en Dart (petit parser custom de ~50 lignes ou package communautaire). Le triplet `(cip13, lot, numero_serie)` permet la détection de boîtes déjà connues (cf. section 3.3).

### 4.9 Base BDPM locale

Téléchargement mensuel des TSV BDPM côté serveur → transformation en SQLite embarqué (~20-30 Mo compressé) → servi comme asset téléchargeable par l'app au premier lancement + mises à jour diff ensuite. Permet la résolution CIP → nom/DCI/dosage **totalement offline**.

**Alternative** : embarquer directement la DB BDPM dans l'APK/IPA (taille app +20-30 Mo), plus simple mais moins flexible pour les mises à jour.

### 4.10 Structure monorepo

```
monorepo/
├── apps/
│   ├── web/                    → Next.js 15 (UI web + backend API)
│   └── mobile/                 → Application Flutter (structure pub classique)
├── packages/
│   ├── db-schema/              → Drizzle schemas + migrations Postgres
│   └── api-contract/           → Schémas Zod + OpenAPI généré
├── scripts/
│   ├── generate-openapi.ts     → zod → openapi.yaml
│   ├── generate-ts-client.sh   → openapi → types TS pour web
│   └── generate-dart-client.sh → openapi → client Dart pour mobile
└── turbo.json                  → Turborepo config (web + packages)
```

**Note** : Flutter vit à côté du monorepo Node. Turborepo gère les packages JS/TS, Flutter garde son propre tooling (`flutter pub`, `flutter build`). Les deux cohabitent sans problème, reliés par le contrat OpenAPI.

### 4.11 Modèle de données simplifié

```
users (id, email, role[particulier|pro], ...)
officines (id, nom, proprietaire_user_id, type[perso|patient], ...)
partages (officine_id, user_id, role[owner|editor|viewer])
boites (id, officine_id, cip13, lot, numero_serie, peremption, ajoutee_le, unites_restantes, statut[active|vide|perimee], ...)
medicaments_bdpm (cis, cip13, denomination, dosage, forme, ...) -- read-only
substances (cis, denomination_dci, dosage_substance) -- read-only
medicaments_resumes_ia (cis, resume_court, genere_le) -- pré-généré, read-only
ordonnances (id, officine_id, prescripteur, date, source[manuelle|ocr])
prescriptions (id, ordonnance_id, cip13_ou_cis, posologie_struct, duree, ...)
prises_planifiees (id, prescription_id, datetime_prevue, statut, datetime_validation)
alertes (id, officine_id, type, payload, lue_le)
pending_operations (id, user_id, type, payload, timestamp_local, statut) -- mobile only
```

**Note sur l'unicité des boîtes** : contrainte d'unicité `(officine_id, lot, numero_serie)`. Si le triplet existe déjà au scan, déclencher la popup d'actions rapides au lieu du flux d'ajout.

**Note sur les suppressions** : pas de `DELETE` réel, toutes les tables métier ont un champ `deleted_at` (soft delete). Nécessaire pour la sync multi-device sans perdre d'opérations.

---

## 5. Conformité & sécurité

### 5.1 Cadre réglementaire — positionnement "carnet de suivi"

**L'app est un carnet numérique personnel** (cf. section 1.5). Elle ne fait **aucun acte médical**, ne valide rien, ne prescrit rien. Conséquences positives :

- **Pas de marquage CE médical** (MDR 2017/745) à prévoir — on n'est pas un dispositif médical.
- **Pas de déclaration ANSM** requise.
- **Pas de certification IA médicale** — même pour l'OCR, c'est un outil d'aide à la saisie pour l'utilisateur, pas une interprétation clinique.
- **Risque juridique contenu** tant que les mentions d'information sont claires ("n'est pas un dispositif médical", "ne remplace pas l'ordonnance officielle").

### 5.2 Le sujet HDS (Hébergement de Données de Santé)

**Même en restant carnet de suivi**, les informations manipulées restent des **données de santé au sens RGPD** : un traitement médicamenteux révèle des pathologies, un schéma posologique aussi. Le cadre HDS s'applique donc toujours pour une mise en production commerciale.

**Pour ce POC** : on ignore la certification HDS, mais on documente la dette. La migration vers un hébergeur HDS (OVH, Scaleway, AWS offre HDS) sera nécessaire avant tout usage par de vrais pros sur de vrais patients identifiables.

**Nuance importante** : la justification d'usage devant la CNIL est plus simple dans ce positionnement. On argumente que c'est un outil d'auto-suivi choisi par l'utilisateur (ou son aidant), pas un traitement automatisé de données médicales au sens clinique.

### 5.3 RGPD — principes à respecter dès le POC

- Consentement explicite à la création de compte.
- Minimisation : on ne collecte que ce qui est nécessaire.
- Chiffrement en transit (HTTPS partout) et au repos (chiffrement disque + champs sensibles).
- Droit à l'effacement : suppression de compte = suppression réelle, pas soft delete.
- Pas de tracking tiers type Google Analytics sur des écrans où figurent des données médicales.
- Registre des traitements à tenir dès que l'app quitte le cercle privé des développeurs.

### 5.4 Authentification & partage

- Auth forte : email + mot de passe (+ 2FA optionnel en v2 pour les pros).
- Invitations à une officine via lien signé + expiration 72h.
- Révocation de partage à tout moment par le propriétaire.
- Audit log des accès : qui a consulté quoi et quand (v2, utile pour les pros).

### 5.5 Sécurité technique

- Rate limiting sur l'API (auth notamment).
- CSRF tokens pour le web.
- Secrets en vault (pas dans le repo).
- Scan de dépendances (npm audit, Dependabot).
- Pas de logs avec données médicales en clair.

---

## 6. Roadmap proposée (1-3 mois MVP)

### 6.1 Planning macro

**Mois 1 — Fondations techniques**
- Setup monorepo Turborepo : `apps/web` (Next.js 15), `apps/mobile` (Flutter), `packages/db-schema`, `packages/api-contract`.
- Postgres managé + Drizzle migrations (source de vérité DB).
- Backend Next.js : premières routes API + validation Zod + pipeline `zod-to-openapi` + génération client Dart.
- App Flutter : bootstrap Riverpod + go_router + Drift (DB locale).
- Import BDPM en SQLite embarqué côté mobile, résolution CIP fonctionnelle offline.
- Scan DataMatrix avec `mobile_scanner`, parsing GS1 (AI 01/10/17/21).
- Auth basique (Better Auth ou Clerk) : email + mot de passe, JWT mobile.
- POC sync : endpoints `/sync/push` + `/sync/pull` + table `pending_operations` côté Flutter.

**Mois 2 — Features cœur particulier**
- CRUD complet officine + boîtes (mobile + web).
- Popup actions rapides au rescan (cf. section 3.3).
- Regroupement par molécule (DCI).
- Création d'ordonnances manuelles + génération de prises planifiées.
- Notifications push (FCM) de rappel de prise + validation.
- Pré-génération des résumés IA des médicaments BDPM (job batch one-shot).
- Polish UX : onboarding, états vides, gestion des erreurs de scan.
- Déploiement web sur Vercel, builds TestFlight + APK interne.

**Mois 3 — Partage et test terrain**
- Modèle de partage avec 3 rôles + invitations par lien signé.
- Vue multi-officines côté mobile + web (bascule rapide pour les pros testeurs).
- Signalement de manque patient → pro (notif push côté pro).
- Durcissement du moteur de sync (retries, gestion des conflits, observabilité).
- Beta fermée avec 3-5 familles + 1-2 pros.
- Recueil de feedback, itérations rapides.

**Sortie M3** : MVP fonctionnel prouvant la valeur sur les 3 priorités du haut du classement. Compte pro en version allégée (une personne qui suit plusieurs officines), OCR et alertes avancées reportés.

### 6.2 Phase 2 (M4-M6) — pas dans le livrable mais à documenter

- Compte pro complet avec dashboard tournée.
- OCR ordonnance (intégration Claude Vision ou Mistral OCR).
- Canaux SMS + email pour notifications.
- Alertes péremption et estimation rupture.

### 6.3 Phase 3+ — vision long terme

- Conformité HDS (migration d'hébergement).
- Intégration Mon espace santé / DMP si ouverture des API.
- Mode famille avec N ayants-droits.
- Application watchOS / Wear OS pour validation de prise au poignet.
- Intégration pharmacie partenaire pour renouvellement en 1 clic.

---

## 7. Estimation d'effort & équipe

### 7.1 Hypothèse d'équipe

| Profil | Charge estimée MVP |
|---|---|
| Dev fullstack (toi) | 3 mois à ~50% (side-project) |
| Dev renfort mobile (si possible) | 1-2 mois à 30% |
| Design UX | 2-3 semaines concentrées M1 |

**Seul sur 3 mois à 50%**, le MVP décrit est **très ambitieux mais atteignable** en resserrant le scope et en acceptant que "polish" soit réduit. Il faudra couper ruthlessly si on dérape.

### 7.2 Budget externe POC

| Poste | Estimation mensuelle POC |
|---|---|
| Hébergement (Railway/Fly) | 20-40 € |
| Auth (Clerk free tier) | 0 € |
| DB managée | inclus ou 15 € |
| Notifs push (Expo) | 0 € |
| SMS (Brevo, 100 SMS test) | 5-10 € |
| Email transac | 0 € (free tier) |
| Nom de domaine | 10 € / an |
| Certificat Apple Developer | 99 € / an |
| Google Play Developer | 25 € (one-shot) |
| **Total POC** | ~50 €/mois + frais fixes |

En prod réelle avec HDS, multiplier par 5-10 selon le volume.

---

## 8. Risques & points de vigilance

| Risque | Impact | Mitigation |
|---|---|---|
| Scope trop ambitieux pour 3 mois | Fort | Priorisation stricte, MVP = 3 premières features seulement |
| Sync custom plus complexe que prévu | Moyen-fort | POC sync dès la fin M1, scénarios de conflit documentés, last-write-wins en MVP |
| Double codebase = charge UI dupliquée | Moyen | Accepté par choix ; se concentrer sur mobile en priorité, web minimal au MVP |
| Parsing DataMatrix GS1 capricieux | Moyen | Tester dès la première semaine sur des boîtes réelles variées (au moins 10) |
| Désynchronisation contrat OpenAPI ↔ clients | Moyen | Pipeline CI qui fail si OpenAPI change sans regen des clients |
| BDPM : mauvais matches CIP | Moyen | Fallback saisie manuelle + report au user |
| Conformité HDS ignorée = bloquant pour vraie prod | Fort (après POC) | Plan de migration documenté, tri des données sensibles anticipé |
| Notifications iOS capricieuses en background | Moyen | Prévoir email/SMS comme backup dès v2 |
| Firebase (FCM) = vendor lock-in léger | Faible | Couche d'abstraction côté backend pour pouvoir changer de provider |
| Concurrence (Medissimo, Medisafe, suites SSIAD) | Moyen | Analyse initiale faite (cf. 1.4), différenciateurs identifiés ; à affiner par tests utilisateurs réels |
| Adoption pros difficile (workflow métier) | Fort | Interviews utilisateurs dès M1 avec 2-3 IDEL/aide-soignants |
| Pré-génération résumés IA coûteuse ou erronée | Moyen | Job batch one-shot, relecture échantillon, possibilité de désactiver résumé IA et retomber sur BDPM brut |
| Numéro de série GS1 absent sur vieilles boîtes | Faible-Moyen | Fallback : identification par (CIP13 + lot) si pas de n° série, prévenir l'utilisateur |

---

## 9. Questions ouvertes à trancher avant le dev

Quelques décisions que je te recommande de prendre rapidement :

1. **Nom du produit et branding** — tu as une idée ? Ça influence le ton, le logo, le domaine à acheter.
2. **Rédaction des mentions d'information** — CGU, disclaimer d'onboarding, texte affiché sur les écrans de saisie d'ordonnance. À faire relire par un juriste avant la beta publique. Idéalement, phrase-type à afficher : *"Ce carnet numérique est un aide-mémoire personnel. Il ne remplace ni votre ordonnance, ni l'avis de votre médecin, pharmacien ou infirmier."*
3. **Validation du pipeline OpenAPI → client Dart** — à POC en première semaine pour vérifier que le workflow de régénération tient la route.
4. **Moteur OCR ordonnance** — Claude, Mistral, ou Gemini ? Les trois ont des capacités vision. À tester sur 10 ordonnances réelles pour comparer.
5. **Monétisation à terme** — freemium ? B2B pros payants ? Gratuit pour particulier + abonnement pro ? Ça influence les choix techniques (multi-tenant, facturation).
6. **Interviews utilisateurs** — peux-tu contacter 2-3 IDEL ou aides-soignants pour les interviewer avant M1 ? C'est le meilleur investissement possible.
7. **Langues** — français only au POC, ou prévoir i18n dès le départ ? Je recommande FR only pour le MVP.
8. **Tests utilisateurs réels** — qui sont les 3-5 familles pressenties pour la beta ?

---

## 10. Prochaines étapes concrètes

1. **Valider ce dossier** avec les parties prenantes (toi + éventuels co-fondateurs).
2. **Interviews utilisateurs** : 2-3 particuliers, 2-3 pros, 1h chacun. Objectif : valider les hypothèses, découvrir des besoins non anticipés.
3. **Approfondir l'analyse concurrentielle** : tests terrain réels sur Medissimo, Medisafe et Preskri (s'inscrire, utiliser pendant 1 semaine, identifier les irritants concrets). L'analyse documentaire (cf. 1.4) est faite, manque l'expérience utilisateur vécue.
4. **POC technique** : en une semaine, prouver que scan DataMatrix → résolution BDPM → enregistrement local → sync serveur fonctionne.
5. **Wireframes low-fi** des 5 écrans principaux : officine, scan, détail médicament, timeline, partage. Pas besoin d'un designer pro à ce stade, Excalidraw ou Figma suffisent.
6. **Lancement du dev MVP** sur la base de ce dossier ajusté.

---

*Fin du document — à amender ensemble lors de la prochaine revue.*
