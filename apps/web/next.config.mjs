/**
 * Static export for GitHub Pages (`output: 'export'`).
 *
 * NEXT_PUBLIC_BASE_PATH must be `/<repo-name>` when building for a project
 * site (https://<owner>.github.io/<repo>/). Locally and for custom domains
 * leave it unset. See .github/workflows/web-deploy.yml.
 *
 * @type {import('next').NextConfig}
 */
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? '';

const nextConfig = {
  output: 'export',
  trailingSlash: true,
  basePath,
  images: { unoptimized: true },
};

export default nextConfig;
