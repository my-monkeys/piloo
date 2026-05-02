// Registry OpenAPI partagé : tous les schémas s'enregistrent ici via
// `registry.register()` ou `registry.registerPath()`. Le script
// `scripts/generate.ts` consomme ce registry pour produire `openapi.yaml`.
import {
  OpenAPIRegistry,
  OpenApiGeneratorV31,
  extendZodWithOpenApi,
} from '@asteasolutions/zod-to-openapi';
import { z } from 'zod';

extendZodWithOpenApi(z);

export const registry = new OpenAPIRegistry();

export interface OpenApiDocumentMeta {
  readonly title: string;
  readonly version: string;
  readonly description: string;
  readonly servers: readonly { readonly url: string; readonly description: string }[];
}

export const documentMeta: OpenApiDocumentMeta = {
  title: 'Piloo API',
  version: '0.0.0',
  description:
    'API REST de Piloo — carnet numérique de médicaments. Source de vérité : les schémas Zod du package @piloo/api-contract.',
  servers: [
    { url: 'http://localhost:3000/api', description: 'Local dev' },
    { url: 'https://piloo.fr/api', description: 'Production' },
  ],
};

export function buildOpenApiDocument(): ReturnType<OpenApiGeneratorV31['generateDocument']> {
  const generator = new OpenApiGeneratorV31(registry.definitions);
  return generator.generateDocument({
    openapi: '3.1.0',
    info: {
      title: documentMeta.title,
      version: documentMeta.version,
      description: documentMeta.description,
    },
    servers: [...documentMeta.servers],
  });
}
