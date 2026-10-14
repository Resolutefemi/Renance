import type { MetadataRoute } from 'next';

// required for output: 'export'
export const dynamic = 'force-static';

/**
 * PWA manifest (app/manifest.ts -> /manifest.webmanifest, auto-linked
 * by Next in <head>). The name/short_name fields double as brand and
 * keyword carriers for Android home-screen installs, browser app
 * listings and Lighthouse - keep them in sync with the root metadata.
 */
export default function manifest(): MetadataRoute.Manifest {
  const base = process.env.NEXT_PUBLIC_BASE_PATH ?? '';
  return {
    name: "Renance - Nigeria's Educational App",
    short_name: 'Renance',
    description:
      "Renance is the educational app in Nigeria: learn JAMB, WAEC, NECO and tertiary institution courses step by step, practise 235,110+ real past questions, win daily quests and climb the leagues.",
    start_url: '/',
    scope: '/',
    display: 'standalone',
    background_color: '#ffffff',
    theme_color: '#111c2d',
    categories: ['education'],
    lang: 'en-NG',
    icons: [
      {
        src: `${base}/icon-192.png`,
        sizes: '192x192',
        type: 'image/png',
        purpose: 'any',
      },
      {
        src: `${base}/renance-mark.png`,
        sizes: '512x512',
        type: 'image/png',
        purpose: 'any',
      },
      {
        src: `${base}/renance-mark.png`,
        sizes: '512x512',
        type: 'image/png',
        purpose: 'maskable',
      },
      {
        // Founder build target: the dedicated 500px store icon.
        src: `${base}/renance-mark-500.png`,
        sizes: '500x500',
        type: 'image/png',
        purpose: 'any',
      },
    ],
  };
}
