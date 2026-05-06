/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  transpilePackages: ['@piloo/api-contract'],
  typedRoutes: true,
};

export default nextConfig;
