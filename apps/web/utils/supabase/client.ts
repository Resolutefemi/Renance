'use client';

/**
 * Supabase browser client (founder directive 2026-10-15: "install the
 * Supabase packages, add the env variables and the client helpers").
 *
 * STATIC-EXPORT NOTE: apps/web builds with `output: 'export'` - there
 * is no server runtime and no middleware at deploy time, so the
 * server-side half of the standard Supabase snippet
 * (utils/supabase/server.ts with next/headers cookies) and a
 * middleware.ts session refresher CANNOT run in this app (a root
 * middleware.ts would fail the static build outright). The browser
 * client below is the static-export-safe half; the app's authoritative
 * data path stays the Go study-api, which talks to Supabase directly
 * as the fallback database (see render.yaml → SUPABASE_DATABASE_URL).
 *
 * VERCEL NOTE (founder directive 2026-10-15: "add it to Vercel
 * yourself"): NEXT_PUBLIC_ values are baked at BUILD time, so the
 * cleanest self-serve deploy is the same doctrine as API_BASE in
 * lib/api.ts - the production fallbacks below carry the project's
 * public-by-design values (the URL and the publishable key; both are
 * safe to expose in client code by Supabase's own design, and this
 * repository is private). Setting NEXT_PUBLIC_SUPABASE_URL /
 * NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY in the Vercel dashboard still
 * works and simply overrides these constants.
 */

import { createBrowserClient } from '@supabase/ssr';

// Project zfxrmcwdnmmxjawmsiyp (eu-west-3). Publishable key = public
// by design (the secret key lives only on the Go study-api side).
const FALLBACK_URL = 'https://zfxrmcwdnmmxjawmsiyp.supabase.co';
const FALLBACK_PUBLISHABLE_KEY = 'sb_publishable_T7XQbiSigWyiSuq-ZQwA0g_wgIW1GnI';

const supabaseUrl =
  process.env.NEXT_PUBLIC_SUPABASE_URL ??
  (process.env.NODE_ENV === 'production' ? FALLBACK_URL : undefined);
const supabaseKey =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
  (process.env.NODE_ENV === 'production' ? FALLBACK_PUBLISHABLE_KEY : undefined);

let cached: ReturnType<typeof createBrowserClient> | null = null;

/** The shared browser client (anon/publishable key, RLS-scoped). */
export function createClient() {
  if (cached) return cached;
  if (!supabaseUrl || !supabaseKey) {
    throw new Error(
      'Supabase is not configured: set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
    );
  }
  cached = createBrowserClient(supabaseUrl, supabaseKey);
  return cached;
}

/**
 * Fire-and-forget REST activity ping (founder directive 2026-10-15:
 * "make sure Supabase is not inactive"). One authenticated REST request
 * per page load counts as project activity on the free tier, so real
 * student traffic keeps the project awake between the scheduled
 * db-keepalive workflow runs. Never throws, never blocks rendering,
 * 4s budget. Returns true when Supabase answered 2xx.
 */
export async function pingSupabase(): Promise<boolean> {
  if (!supabaseUrl || !supabaseKey) return false;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 4000);
    try {
      const res = await fetch(`${supabaseUrl}/rest/v1/`, {
        headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` },
        signal: controller.signal,
      });
      return res.ok;
    } finally {
      clearTimeout(timer);
    }
  } catch {
    return false;
  }
}
