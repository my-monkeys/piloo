# Modèle de données — Piloo

Ce document décrit le schéma PostgreSQL du backend et la base SQLite locale (mobile). Les deux sont structurellement similaires, avec des différences notées.

---

## Conventions globales

- **IDs** : `UUID v4` générés côté client pour permettre la création offline sans collision.
- **Timestamps** : `timestamptz` côté Postgres, `DATETIME` côté SQLite. Toujours UTC.
- **Soft delete** : toutes les tables métier ont `deleted_at` nullable (suppression = SET deleted_at = now()).
- **Audit** : `created_at`, `updated_at` sur toutes les tables métier.
- **Casing** : `snake_case` côté DB, converti en `camelCase` côté clients via les générateurs OpenAPI.

---

## Tables métier

### `users`

Utilisateurs du service.

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| id | UUID | PK | |
| email | TEXT | UNIQUE NOT NULL | Identifiant de connexion |
| password_hash | TEXT | NOT NULL | bcrypt ou argon2 |
| email_verified_at | TIMESTAMPTZ | NULL | Null tant que non vérifié |
| nom | TEXT | NOT NULL | |
| prenom | TEXT | NOT NULL | |
| type_compte | ENUM('particulier', 'pro') | NOT NULL | |
| telephone | TEXT | NULL | Format E.164 |
| preferences | JSONB | NOT NULL DEFAULT '{}' | Notifications, langue, fuseau, etc. |
| created_at | TIMESTAMPTZ | NOT NULL DEFAULT now() | |
| updated_at | TIMESTAMPTZ | NOT NULL DEFAULT now() | |
| deleted_at | TIMESTAMPTZ | NULL | |
| last_login_at | TIMESTAMPTZ | NULL | |

**Index** : `idx_users_email` sur email (unique), `idx_users_deleted_at`.

---

### `officines`

Contenant logique d'un ensemble de boîtes de médicaments.

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| id | UUID | PK | |
| nom | TEXT | NOT NULL | "Maison", "Mme Dubois", etc. |
| type | ENUM('perso', 'patient') | NOT NULL | |
| proprietaire_user_id | UUID | FK users.id NOT NULL | |
| date_naissance | DATE | NULL | Pour posologies adaptées |
| notes | TEXT | NULL | Allergies, précautions, contacts |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| deleted_at | TIMESTAMPTZ | NULL | |

**Index** : `idx_officines_proprietaire` sur proprietaire_user_id.

**Règles métier**
- Un compte `particulier` a 1 officine `perso` créée automatiquement.
- Un compte `pro` crée des officines type `patient` à la demande.

---

### `partages`

Relation many-to-many entre utilisateurs et officines, avec rôle.

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| id | UUID | PK | |
| officine_id | UUID | FK officines.id NOT NULL | |
| user_id | UUID | FK users.id NOT NULL | |
| role | ENUM('owner', 'editor', 'viewer') | NOT NULL | |
| invited_by | UUID | FK users.id NULL | |
| invited_at | TIMESTAMPTZ | NOT NULL | |
| accepted_at | TIMESTAMPTZ | NULL | Null = invitation non acceptée |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| deleted_at | TIMESTAMPTZ | NULL | |

**Contrainte** : UNIQUE (officine_id, user_id) WHERE deleted_at IS NULL.

**Règles métier**
- Le propriétaire de l'officine a automatiquement un partage `owner`.
- Révocation = SET deleted_at (soft delete) pour garder l'historique.

---

### `boites`

Boîtes physiques de médicament dans une officine.

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| id | UUID | PK | |
| officine_id | UUID | FK officines.id NOT NULL | |
| cip13 | TEXT | NOT NULL | Code CIP13 (13 chiffres) |
| lot | TEXT | NULL | Numéro de lot GS1 AI(10) |
| numero_serie | TEXT | NULL | GS1 AI(21), NULL pour vieilles boîtes |
| peremption | DATE | NOT NULL | Date de péremption |
| unites_initiales | INT | NULL | Nombre d'unités à l'origine (depuis BDPM) |
| unites_restantes | INT | NULL | Stock courant estimé |
| statut | ENUM('active', 'vide', 'perimee') | NOT NULL DEFAULT 'active' | |
| notes | TEXT | NULL | |
| ajoutee_par | UUID | FK users.id NOT NULL | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| deleted_at | TIMESTAMPTZ | NULL | |

**Index**
- `idx_boites_officine_statut` sur (officine_id, statut) pour l'inventaire actif.
- `idx_boites_cip13` pour regroupement par médicament.
- `idx_boites_peremption` pour les alertes péremption.

**Contrainte d'unicité** : UNIQUE (officine_id, cip13, lot, numero_serie) WHERE deleted_at IS NULL.

> Si numero_serie est NULL et lot existe, contrainte sur (officine_id, cip13, lot).
> Si les deux sont NULL, plusieurs boîtes identiques sont possibles (fallback vieilles boîtes).

---

### `ordonnances`

Prescription saisie par un utilisateur (manuelle ou via OCR).

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| id | UUID | PK | |
| officine_id | UUID | FK officines.id NOT NULL | |
| prescripteur | TEXT | NULL | Texte libre : "Dr Martin, cardiologue" |
| date_prescription | DATE | NOT NULL | |
| source | ENUM('manuelle', 'ocr') | NOT NULL DEFAULT 'manuelle' | |
| photo_url | TEXT | NULL | URL S3 si OCR (stockée chiffrée) |
| notes | TEXT | NULL | |
| saisie_par | UUID | FK users.id NOT NULL | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| deleted_at | TIMESTAMPTZ | NULL | |

**Index** : `idx_ordonnances_officine`.

---

### `prescriptions`

Une ligne d'une ordonnance : un médicament + posologie.

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| id | UUID | PK | |
| ordonnance_id | UUID | FK ordonnances.id NOT NULL | |
| cip13 | TEXT | NULL | CIP13 si médicament précis |
| cis | TEXT | NULL | CIS si seulement spécialité (pas de présentation précise) |
| nom_texte | TEXT | NOT NULL | Nom tel qu'affiché (depuis BDPM ou saisie) |
| posologie | JSONB | NOT NULL | Cf. structure ci-dessous |
| duree_jours | INT | NULL | NULL = traitement à vie |
| indication | TEXT | NULL | |
| notes | TEXT | NULL | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| deleted_at | TIMESTAMPTZ | NULL | |

**Structure `posologie` (JSONB)**
```json
{
  "unites_par_prise": 1,
  "unite": "comprimé",
  "frequence": "quotidien",
  "moments": ["matin", "midi", "soir"],
  "horaires": ["08:00", "12:00", "19:00"],
  "avec_repas": true,
  "espacement_minutes": null
}
```

**Index** : `idx_prescriptions_ordonnance`, `idx_prescriptions_cip13`.

---

### `prises_planifiees`

Occurrence d'une prise, générée à partir d'une prescription.

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| id | UUID | PK | |
| prescription_id | UUID | FK prescriptions.id NOT NULL | |
| officine_id | UUID | FK officines.id NOT NULL | Redondant mais utile pour index |
| datetime_prevue | TIMESTAMPTZ | NOT NULL | |
| datetime_validation | TIMESTAMPTZ | NULL | |
| statut | ENUM('prevue', 'prise', 'sautee', 'oubliee') | NOT NULL DEFAULT 'prevue' | |
| validee_par | UUID | FK users.id NULL | |
| notes | TEXT | NULL | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| deleted_at | TIMESTAMPTZ | NULL | |

**Index**
- `idx_prises_officine_datetime` sur (officine_id, datetime_prevue) pour timeline.
- `idx_prises_statut_datetime` pour le job "oubliée".

**Règles métier**
- Générées en batch à la création de la prescription (30 jours d'avance si "à vie").
- Job cron toutes les 15 min : passe en `oubliee` les `prevue` avec datetime_prevue < now - 1h.

---

### `alertes`

Notifications applicatives persistées pour audit et badge "alertes non lues".

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| id | UUID | PK | |
| officine_id | UUID | FK officines.id NOT NULL | |
| user_id | UUID | FK users.id NOT NULL | Destinataire |
| type | ENUM(...) | NOT NULL | Cf. spec.md section 6.1 |
| payload | JSONB | NOT NULL | Contexte (boite_id, prescription_id, ...) |
| lue_a | TIMESTAMPTZ | NULL | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| deleted_at | TIMESTAMPTZ | NULL | |

**Index** : `idx_alertes_user_lue_a` pour badges et listes non lues.

---

## Tables référentielles (read-only)

### `medicaments_bdpm`

Miroir de la base BDPM officielle. Alimentée par job cron mensuel.

| Colonne | Type | Description |
|---|---|---|
| cis | TEXT PK | Code CIS (spécialité) |
| cip13 | TEXT | Code CIP13 (présentation) |
| cip7 | TEXT | Code CIP7 |
| denomination | TEXT | Nom complet "DOLIPRANE 1000mg cp" |
| forme | TEXT | "comprimé", "gélule"... |
| dosage | TEXT | "1000mg" |
| voie_administration | TEXT | "orale", "cutanée"... |
| titulaire | TEXT | Laboratoire |
| statut_amm | TEXT | "Autorisation active", ... |
| taux_remboursement | INT | 0, 15, 30, 65, 100 |
| version_bdpm | DATE | Date de l'import source |

**Index** : `idx_bdpm_cip13`, `idx_bdpm_denomination_trgm` (pg_trgm pour recherche textuelle).

### `substances`

Principes actifs (DCI) d'un médicament.

| Colonne | Type | Description |
|---|---|---|
| id | SERIAL PK | |
| cis | TEXT FK medicaments_bdpm.cis | |
| code_substance | TEXT | |
| denomination_dci | TEXT | "PARACETAMOL" |
| dosage_substance | TEXT | "1000 mg" |

**Index** : `idx_substances_cis`, `idx_substances_dci`.

### `medicaments_resumes_ia`

Résumés courts générés par IA (pré-générés, pas à la volée).

| Colonne | Type | Description |
|---|---|---|
| cis | TEXT PK FK medicaments_bdpm.cis | |
| resume_court | TEXT | 2-3 phrases |
| genere_par | TEXT | "claude-haiku-4-5" |
| genere_le | TIMESTAMPTZ | |
| version_bdpm_source | DATE | |

---

## Tables spécifiques côté serveur

### `pending_invitations`

Invitations en cours (avant acceptation).

| Colonne | Type | Description |
|---|---|---|
| id | UUID PK | |
| officine_id | UUID FK | |
| email_invite | TEXT | |
| role | ENUM | |
| token | TEXT UNIQUE | Token signé JWT |
| expires_at | TIMESTAMPTZ | |
| invited_by | UUID FK users.id | |
| used_at | TIMESTAMPTZ NULL | |
| created_at | TIMESTAMPTZ | |

### `sync_cursor` (optionnel)

Marque le dernier timestamp de sync par device. Peut aussi être géré côté client.

---

## Tables spécifiques côté mobile (SQLite via Drift)

### `pending_operations`

File d'attente pour la sync offline-first.

| Colonne | Type | Description |
|---|---|---|
| id | TEXT PK | UUID v4 |
| type | TEXT | "create_boite", "update_stock", "mark_prise"... |
| entity_type | TEXT | "boite", "prise", ... |
| entity_id | TEXT | |
| payload | TEXT | JSON stringifié |
| timestamp_local | INTEGER | Unix millis |
| statut | TEXT | "pending" / "syncing" / "synced" / "failed" |
| attempts | INTEGER DEFAULT 0 | |
| last_error | TEXT NULL | |
| created_at | INTEGER | |

**Index** : `idx_pending_statut` pour récupérer les pending au prochain sync.

### `sync_state`

État global de la sync.

| Colonne | Type | Description |
|---|---|---|
| key | TEXT PK | "last_pull_at", "bdpm_version"... |
| value | TEXT | |

---

## Relations & invariants

```
users 1─────N officines (proprietaire_user_id)
users N─────N officines via partages
officines 1───N boites
officines 1───N ordonnances
ordonnances 1─N prescriptions
prescriptions 1─N prises_planifiees
officines 1───N alertes
medicaments_bdpm 1───N substances
medicaments_bdpm 1───1 medicaments_resumes_ia
```

**Invariants à maintenir (vérifiés par le backend)**
- Un utilisateur ne peut voir/modifier une boîte/ordonnance/prise que s'il a un partage actif sur l'officine correspondante avec le bon rôle.
- `unites_restantes <= unites_initiales` si les deux sont non NULL.
- `statut = 'perimee'` si `peremption < today` (recalculé par un job cron nocturne).
- Une prise `prise` doit avoir `datetime_validation` non NULL et `validee_par` non NULL.

---

## Migrations initiales

Ordre de création recommandé :
1. `users`
2. `officines`
3. `partages`
4. `medicaments_bdpm` + `substances` + `medicaments_resumes_ia` (référentiel)
5. `boites`
6. `ordonnances`
7. `prescriptions`
8. `prises_planifiees`
9. `alertes`
10. `pending_invitations`
