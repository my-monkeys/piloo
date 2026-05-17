// Barrel des schémas Zod. Chaque module enregistre ses paths dans le
// registry OpenAPI à l'import — ne pas oublier d'importer ici les nouveaux
// schémas pour qu'ils apparaissent dans openapi.yaml.
export * from './health.ts';
export * from './officines.ts';
export * from './boites.ts';
export * from './sync.ts';
export * from './alertes.ts';
export * from './manque.ts';
export * from './notif-prefs.ts';
export * from './bdpm.ts';
export * from './prises.ts';
export * from './devices.ts';
export * from './ordonnances.ts';
export * from './export-data.ts';
export * from './account-delete.ts';
