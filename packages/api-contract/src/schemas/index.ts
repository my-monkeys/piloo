// Barrel des schémas Zod. Chaque module enregistre ses paths dans le
// registry OpenAPI à l'import — ne pas oublier d'importer ici les nouveaux
// schémas pour qu'ils apparaissent dans openapi.yaml.
export * from './health.ts';
