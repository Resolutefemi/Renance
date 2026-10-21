'use client';

/**
 * SwRegister: mounts the offline navigation shield (public/sw.js).
 *
 * The site is a static export; when the connection drops mid-route the
 * Next router can fall back to a raw RSC payload page (the
 * /courses/index.txt report, 2026-10-15). The worker intercepts failed
 * NAVIGATIONS and serves the clean /offline state instead.
 *
 * Registered in production builds only - `next dev` reloads bundles on
 * every edit and a worker would serve stale chunks mid-HMR.
 */

import { useEffect } from 'react';
import { pingSupabase } from '@/utils/supabase/client';
import { API_BASE } from '@/lib/api';

const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? '';

export default function SwRegister() {
  useEffect(() => {
    if (
      process.env.NODE_ENV !== 'production' ||
      typeof navigator === 'undefined' ||
      !('serviceWorker' in navigator)
    ) {
      return;
    }
    const src = `${BASE_PATH}/sw.js`;
    navigator.serviceWorker.register(src, { scope: `${BASE_PATH}/` }).catch(() => {
      /* a failed registration never breaks the page - the raw-text
       * fallback simply stays as it was */
    });
    // Supabase activity ping (founder directive 2026-10-15: "make sure
    // Supabase is not inactive"): one fire-and-forget authenticated REST
    // request per production page load counts as project activity, so
    // real student traffic keeps the fallback project awake between the
    // scheduled db-keepalive workflow runs. Never blocks, never throws.
    void pingSupabase();
    // Study-API warm beacon (founder report 2026-10-15: "it's saying
    // the study API is not answering"): Render's free plan spins the
    // API down after ~15 idle minutes and the wake-up can outrun the
    // client's 45s timeout. One fire-and-forget GET /healthz per page
    // load starts that warm-up the moment a student opens the app -
    // by the time they tap anything that needs the database, the
    // service is usually already listening. /healthz is DB-free by
    // doctrine, so this never wakes Neon on its own. Never blocks.
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    fetch(`${API_BASE}/healthz`, { signal: controller.signal, mode: 'no-cors' })
      .catch(() => {})
      .finally(() => clearTimeout(timer));
  }, []);
  return null;
}
