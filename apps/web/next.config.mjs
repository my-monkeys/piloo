import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '../../');

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Build autonome pour le déploiement conteneurisé (cookie-server, #357).
  // `outputFileTracingRoot` pointe sur la racine du monorepo, sinon le tracing
  // ne suit pas les deps workspace (@piloo/*) et le bundle standalone est
  // incomplet au runtime.
  output: 'standalone',
  outputFileTracingRoot: repoRoot,
  reactStrictMode: true,
  transpilePackages: ['@piloo/api-contract', '@piloo/api-client'],
  typedRoutes: true,
  async headers() {
    return [
      {
        source: '/.well-known/apple-app-site-association',
        headers: [{ key: 'Content-Type', value: 'application/json' }],
      },
    ];
  },
  async redirects() {
    return [
      // Raccourcis SEO/branding pour les pages légales (#96). Les pages
      // canoniques restent sous /legal/* pour rester groupées dans
      // l'arborescence — ces URLs courtes pointent dessus.
      { source: '/cgu', destination: '/legal/cgu', permanent: true },
      { source: '/privacy', destination: '/legal/privacy', permanent: true },
      { source: '/mentions', destination: '/legal/mentions', permanent: true },
    ];
  },
};

export default nextConfig;
