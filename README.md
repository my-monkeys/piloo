# Piloo

Carnet numérique de médicaments. Pont léger patient ↔ pro de santé.

**Project hub** : https://piloo-project.my-monkey.fr/

## Stack

- **Mobile** : Flutter 3.x + Drift (SQLite)
- **Web + API** : Next.js 15 (App Router) + TypeScript + Zod
- **DB** : PostgreSQL + Drizzle
- **Sync** : custom append-only operations log + last-write-wins
- **Auth** : Better Auth ou Clerk (à trancher M1)
- **Notifications** : FCM + Brevo

## Documentation

Toutes les specs sont sur le hub : https://piloo-project.my-monkey.fr/

- [Dossier de cadrage](https://piloo-project.my-monkey.fr/docs/viewer.html?doc=dossier-cadrage.md)
- [Spécifications](https://piloo-project.my-monkey.fr/docs/viewer.html?doc=spec.md)
- [Architecture](https://piloo-project.my-monkey.fr/docs/viewer.html?doc=architecture.md)
- [Data model](https://piloo-project.my-monkey.fr/docs/viewer.html?doc=data-model.md)
- [API contract](https://piloo-project.my-monkey.fr/docs/viewer.html?doc=api-contract.md)
- [UI/UX guidelines](https://piloo-project.my-monkey.fr/docs/viewer.html?doc=ui-ux-guidelines.md)
- [Roadmap](https://piloo-project.my-monkey.fr/docs/viewer.html?doc=roadmap.md)
- [Design recap (25 écrans mobile)](https://piloo-project.my-monkey.fr/design/recap.html)

## Repo structure (à venir)

```
piloo/
├── apps/
│   ├── mobile/          # Flutter
│   └── web/             # Next.js (web + API)
├── packages/
│   ├── db-schema/       # Drizzle schema partagée
│   └── api-contract/    # Zod + OpenAPI
└── docs/                # Specs source
```

## Positionnement

Piloo est un **carnet de suivi personnel**, **pas un dispositif médical** au sens MDR. Pas de validation clinique, pas de recommandation médicale.
