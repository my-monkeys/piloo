# syntax=docker/dockerfile:1
#
# Image de l'app web Piloo (Next.js 15) pour le déploiement self-hosté sur
# cookie-server (#357). Monorepo pnpm + Turborepo : le contexte de build est
# la racine du repo. Les fichiers OpenAPI générés sont commités, donc pas de
# régénération (ni de Java, qui n'est requis que pour le client Dart mobile).

FROM node:22-slim AS base
ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
ENV NEXT_TELEMETRY_DISABLED=1
RUN corepack enable
WORKDIR /app

# --- Build : install + next build (output: standalone) ---
FROM base AS build
COPY . .
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile
RUN pnpm --filter web build

# --- Runner : serveur standalone seul (image minimale, sans toolchain) ---
FROM base AS runner
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# Le standalone monorepo place le serveur sous apps/web/server.js et trace
# ses node_modules à la racine. static/ et public/ ne sont pas tracés : on les
# copie explicitement dans l'arborescence nichée attendue par le serveur.
COPY --from=build --chown=node:node /app/apps/web/.next/standalone ./
COPY --from=build --chown=node:node /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=build --chown=node:node /app/apps/web/public ./apps/web/public

USER node
EXPOSE 3000
CMD ["node", "apps/web/server.js"]
