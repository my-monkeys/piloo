# Audit RGPD interne — Piloo

> Auto-évaluation par rapport à la checklist CNIL pour responsable de
> traitement. État au moment de l'audit ci-dessous. Date à mettre à jour
> à chaque revue.

**Dernière mise à jour** : 2026-05-17
**Auditeur** : Claude Code (auto-évaluation initiale, à valider par DPO/juriste)
**Phase produit** : MVP, pas encore en production commerciale

---

## Légende

- ✅ **Conforme** — implémenté et vérifiable dans le code
- 🟡 **Partiel** — partiellement couvert, action restante
- ⚠️ **Non conforme** — bloquant pour la mise en prod commerciale
- ➖ **Non applicable** au stade actuel

---

## 1. Cartographie des traitements

| Critère                             | État | Référence                                                                      |
| ----------------------------------- | ---- | ------------------------------------------------------------------------------ |
| Registre des traitements documenté  | 🟡   | Ce doc + `docs/data-model.md` ; à formaliser dans le registre CNIL Article 30  |
| Identification des finalités        | ✅   | `docs/dossier-cadrage.md`                                                      |
| Identification base légale          | 🟡   | Compte = exécution du contrat ; partage = consentement → à expliciter dans CGU |
| Catégories de personnes concernées  | ✅   | Patients (particuliers), pros de santé                                         |
| Catégories de données traitées      | ✅   | `docs/data-model.md`                                                           |
| Durée de conservation par catégorie | ⚠️   | À définir + écrire une rétention policy                                        |

**Actions** :

- Rédiger un registre des traitements format CNIL (template officiel).
- Définir une durée de conservation par table (compte actif, alertes, ordonnances post-fin de traitement, etc.).

## 2. Droits des personnes

| Droit RGPD             | Article | État | Référence                                                                      |
| ---------------------- | ------- | ---- | ------------------------------------------------------------------------------ |
| Information            | 13-14   | 🟡   | Politique de confidentialité à écrire (placeholder dans `apps/web/app/legal/`) |
| Accès                  | 15      | ✅   | `POST /api/v1/me/export` (#158)                                                |
| Rectification          | 16      | ✅   | `PATCH /api/v1/me` (#162)                                                      |
| Effacement             | 17      | ✅   | `POST /api/v1/me/delete` + cron J+7 (#159)                                     |
| Limitation             | 18      | ✅   | Effacement = suspension réversible J+7                                         |
| Portabilité            | 20      | ✅   | Même endpoint qu'accès, format JSON documenté (`format_version`)               |
| Opposition             | 21      | ✅   | `PUT /api/v1/me/preferences/notifications`                                     |
| Décisions automatisées | 22      | ➖   | Pas de profilage automatisé dans Piloo                                         |

**Actions** :

- Rédiger et publier `apps/web/app/legal/confidentialite/page.tsx`.
- Référencer `docs/procedures-rgpd.md` depuis la politique.

## 3. Consentement

| Critère                                              | État | Référence                                                                    |
| ---------------------------------------------------- | ---- | ---------------------------------------------------------------------------- |
| Consentement libre / spécifique / éclairé / univoque | 🟡   | Banner cookies #160 ✓ ; consentement données médicales à formaliser dans CGU |
| Retrait aussi simple que le don                      | ✅   | Préférences notifs + suppression compte                                      |
| Pas de pré-cochage                                   | ✅   | `apps/web/lib/cookies/consent.tsx` — refus par défaut                        |
| Consentement mineur < 15 ans                         | ⚠️   | À ajouter au signup : validation parentale obligatoire                       |

**Actions** :

- Ajouter step "âge ≥ 15 ans ou consentement parental" au signup.

## 4. Sécurité des données

| Critère                  | État | Référence                                                                               |
| ------------------------ | ---- | --------------------------------------------------------------------------------------- |
| Chiffrement en transit   | ✅   | HTTPS partout (Vercel + Better Auth obligent)                                           |
| Chiffrement au repos     | 🟡   | Postgres : dépend de l'hébergeur final (#181 Neon recommandé — Neon chiffre par défaut) |
| Authentification forte   | ✅   | Better Auth + sign-in social Apple/Google + email password                              |
| Gestion des sessions     | ✅   | Cookies HttpOnly SameSite=Strict (Better Auth)                                          |
| Logs sans PII            | ✅   | `log.info` n'expose que user_id, jamais email/nom (cf. CLAUDE.md règle 4)               |
| Sauvegardes chiffrées    | 🟡   | Dépend hébergeur (Neon backups OK)                                                      |
| Tests de pénétration     | ⚠️   | À planifier avant mise en prod commerciale                                              |
| Mises à jour de sécurité | 🟡   | Dependabot/Renovate à configurer dans `.github/workflows`                               |

**Actions** :

- Activer Dependabot ou Renovate.
- Planifier un pentest avant prod (cf. `docs/roadmap.md`).
- Stocker les secrets en variables d'env Vercel (déjà le cas, à documenter).

## 5. Données de santé — exigences spécifiques

Les médicaments, posologies et prises sont des **données concernant la
santé** au sens de l'article 9.1 RGPD. Régime renforcé :

| Critère                                        | État | Référence                                                                                                                                 |
| ---------------------------------------------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Base légale article 9.2                        | 🟡   | "Consentement explicite" + "intérêt vital" du patient — à expliciter en CGU                                                               |
| Hébergement HDS (Hébergement Données de Santé) | ⚠️   | **Bloquant pour la prod commerciale**. POC OK sur Neon, prod nécessite un hébergeur certifié HDS (cf. `docs/roadmap.md` jalon HDS, #164)  |
| Pas de transfert hors UE                       | 🟡   | Vercel = US par défaut ; cf. `regions: ["cdg1"]` dans vercel.json mais le control plane Vercel reste US. À documenter dans le DPA Vercel. |
| Pas d'analytics tiers sur écrans médicaux      | ✅   | `CLAUDE.md` règle "pas de tracking tiers"                                                                                                 |
| Logs sans noms de médicaments                  | ✅   | Loggé avec IDs uniquement                                                                                                                 |

**Actions bloquantes pour prod commerciale** :

- Migrer vers un hébergeur HDS (#164, post-MVP).
- Audit transferts hors UE → restreindre Vercel aux régions UE, documenter le control plane.

## 6. Sous-traitants

| Sous-traitant                    | Données traitées                                | DPA signé                     | Référence                                               |
| -------------------------------- | ----------------------------------------------- | ----------------------------- | ------------------------------------------------------- |
| Vercel                           | Hosting front + API (control plane US)          | ❌ À signer (#163)            | https://vercel.com/legal/dpa                            |
| Neon (envisagé)                  | Postgres (control plane US, données EU)         | ❌ À signer                   | https://neon.tech/dpa                                   |
| Brevo (futur)                    | Email + SMS transactionnels                     | ❌ À signer (#163)            | https://www.brevo.com/legal/termsofuse/#data-processing |
| Firebase FCM (futur)             | Push notifs (token + payload notif)             | ❌ À signer (#163)            | https://cloud.google.com/terms/data-processing-addendum |
| Better Auth                      | Bibliothèque self-hosted, pas de sous-traitance | ➖                            | —                                                       |
| Anthropic API (futur résumés IA) | Données posologie/molécule anonymes uniquement  | ❌ Si utilisé en prod, signer | https://www.anthropic.com/legal/dpa                     |

**Actions** :

- Cf. #163 — signer et stocker tous les DPAs dans un drive partagé.

## 7. Notification de violations

| Critère                                   | État | Référence                                     |
| ----------------------------------------- | ---- | --------------------------------------------- |
| Procédure interne de gestion d'incident   | ⚠️   | À écrire — runbook violation de données       |
| Notification CNIL ≤ 72h                   | ⚠️   | Procédure à écrire, contact CNIL à identifier |
| Notification utilisateurs si risque élevé | ⚠️   | Templates email à préparer                    |

**Actions** :

- Rédiger `docs/runbook-violation-donnees.md`.

## 8. DPO et registre

| Critère                 | État | Référence                                                                                            |
| ----------------------- | ---- | ---------------------------------------------------------------------------------------------------- |
| Désignation DPO         | ⚠️   | Obligatoire si traitement à grande échelle de données de santé. À désigner avant prod commerciale.   |
| Registre Article 30     | ⚠️   | À constituer (template CNIL).                                                                        |
| AIPD (Analyse d'Impact) | ⚠️   | Obligatoire pour traitement de données de santé à grande échelle. À réaliser avant prod commerciale. |

**Actions bloquantes prod** :

- Désigner un DPO (interne ou externalisé).
- Réaliser une AIPD complète (utiliser l'outil PIA de la CNIL).
- Constituer le registre Article 30.

---

## TODO list de remédiation — priorités

### Avant beta interne (M2/M3)

1. ⚠️ Rédiger la politique de confidentialité (page `/legal/confidentialite`)
2. ⚠️ Définir durées de conservation par table → écrire policy
3. ⚠️ Ajouter validation âge ≥ 15 ans au signup
4. ⚠️ Activer Dependabot/Renovate
5. ⚠️ Référencer `docs/procedures-rgpd.md` depuis la politique publiée

### Avant mise en prod commerciale (M3+ / hors-MVP)

6. ⚠️ Migrer hébergement vers HDS (#164)
7. ⚠️ Signer tous les DPAs sous-traitants (#163)
8. ⚠️ Désigner un DPO
9. ⚠️ Réaliser une AIPD complète (outil PIA CNIL)
10. ⚠️ Constituer le registre Article 30 (template CNIL)
11. ⚠️ Pentest tiers
12. ⚠️ Rédiger runbook violation de données
13. ⚠️ Préparer templates de notification utilisateurs en cas de violation

### Continu

14. 🔁 Re-faire cet audit à chaque évolution significative (nouvelle source de données, nouveau sous-traitant, nouveau pays d'hébergement)
15. 🔁 Mettre à jour le registre Article 30 à chaque ajout de table ou de traitement

---

## Références

- [Guide CNIL pour les responsables de traitement](https://www.cnil.fr/fr/comprendre-le-rgpd)
- [Template registre Article 30](https://www.cnil.fr/fr/RGPD-le-registre-des-activites-de-traitement)
- [Outil PIA CNIL](https://www.cnil.fr/fr/outil-pia-telechargez-et-installez-le-logiciel-de-la-cnil)
- [Référentiel HDS](https://esante.gouv.fr/labels-certifications/hds)
- `docs/procedures-rgpd.md` — workflow utilisateur des 5 droits
- `docs/dossier-cadrage.md` — finalités du traitement
- `docs/data-model.md` — données traitées
