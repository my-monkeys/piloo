// Point d'entrée public du contrat API. Les consommateurs (apps/web,
// scripts) importent les schémas Zod ici pour valider request/response.
export { buildOpenApiDocument, documentMeta, registry } from './openapi.ts';
export * from './schemas/index.ts';
